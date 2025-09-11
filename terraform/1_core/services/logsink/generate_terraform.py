import csv
import re
import os
from dataclasses import dataclass
from typing import List, Tuple

# --- 定数 ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_CSV_FILE = os.path.join(SCRIPT_DIR, 'sinks.csv')
OUTPUT_DEST_FILE = os.path.join(SCRIPT_DIR, 'destinations.tf')
OUTPUT_SINKS_FILE = os.path.join(SCRIPT_DIR, 'sinks.tf')
OUTPUT_IAM_FILE = os.path.join(SCRIPT_DIR, 'iam.tf')

DESTINATION_CONFIG = {
    'bigquery': {
        'uri_template': "bigquery.googleapis.com/projects/${{data.terraform_remote_state.project.outputs.project_id}}/datasets/{parent}",
        'iam_role': "roles/bigquery.dataEditor",
    },
    'cloud storage': {
        'uri_template': "storage.googleapis.com/{parent}",
        'iam_role': "roles/storage.objectCreator",
    },
}

@dataclass
class Sink:
    log_type: str
    filter: str
    destination_type: str
    destination_parent: str
    retention_days: int

    @property
    def tf_resource_name(self) -> str:
        translation_map = {
            '管理アクティビティ監査ログ': 'admin_activity_audit_logs',
            'データアクセス監査ログ': 'data_access_audit_logs',
            'セキュリティ監査ログ': 'security_audit_logs',
            'アクセスログ': 'access_logs',
            'VPCフローログ': 'vpc_flow_logs',
            'エラーログ': 'error_logs',
            'システムイベントログ': 'system_event_logs',
            'ポリシー違反ログ': 'policy_violation_logs',
            '課金ログ': 'billing_logs',
            'カスタムログ': 'custom_logs',
        }
        name = translation_map.get(self.log_type, self.log_type)
        s = re.sub(r'[^a-zA-Z0-9_ ]', '', name).strip().lower()
        return re.sub(r'\s+', '_', s)

# BigQueryデータセットHCL生成
def generate_dataset_hcl(datasets: List[Tuple[str, int]]) -> str:
    parts = []
    for ds, days in sorted(datasets, key=lambda x: x[0]):
        expiration_ms = days * 24 * 60 * 60 * 1000
        parts.append(f'''resource "google_bigquery_dataset" "{ds}" {{
  project                       = data.terraform_remote_state.project.outputs.project_id
  dataset_id                    = "{ds}"
  location                      = var.region
  delete_contents_on_destroy    = var.bq_dataset_delete_contents_on_destroy
  default_table_expiration_ms = {expiration_ms}

  labels = {{
    purpose = "log-sink-destination"
  }}
}}\n\n''')
    return "".join(parts)

# GCSバケットHCL生成（固定ストレージクラス変更ルール＋削除）
def generate_bucket_hcl(buckets: List[Tuple[str, int]]) -> str:
    parts = []
    for bkt, days in sorted(buckets, key=lambda x: x[0]):
        resource_name = re.sub(r'[^a-zA-Z0-9_]', '_', bkt).lower()
        parts.append(f'''resource "google_storage_bucket" "{resource_name}" {{
  project                       = data.terraform_remote_state.project.outputs.project_id
  name                          = "{bkt}"
  location                      = var.region
  uniform_bucket_level_access = true

  # 30日→Nearline、90日→Coldline、365日→Archive
  lifecycle_rule {{
    action {{
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }}
    condition {{
      age = 30
    }}
  }}

  lifecycle_rule {{
    action {{
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }}
    condition {{
      age = 90
    }}
  }}

  lifecycle_rule {{
    action {{
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }}
    condition {{
      age = 365
    }}
  }}

  # retention_daysで削除
  lifecycle_rule {{
    action {{
      type = "Delete"
    }}
    condition {{
      age = {days}
    }}
  }}

  versioning {{
    enabled = true
  }}
}}\n\n''')
    return "".join(parts)

# Sink HCL生成
def generate_sink_hcl(sink: Sink) -> str:
    config = DESTINATION_CONFIG.get(sink.destination_type.lower())
    if not config:
        return ""
    destination_uri = config['uri_template'].format(parent=sink.destination_parent)
    escaped_filter = sink.filter.replace('"', '\\"')
    bigquery_options_block = ""
    if sink.destination_type.lower() == 'bigquery':
        # ★★★ 修正点 ★★★
        # この文字列はf-stringではないため、{{ }}ではなく {} を使用します。
        bigquery_options_block = """
  bigquery_options {
    use_partitioned_tables = true
  }"""
    return f'''resource "google_logging_organization_sink" "{sink.tf_resource_name}_sink" {{
  provider    = google-beta
  name        = "org-{sink.tf_resource_name}-sink"
  org_id      = data.external.org_id.result.organization_id
  filter      = "{escaped_filter}"
  destination = "{destination_uri}"{bigquery_options_block}
}}\n\n'''

# IAM HCL生成
def generate_iam_hcl(sink: Sink) -> str:
    config = DESTINATION_CONFIG.get(sink.destination_type.lower())
    if not config:
        return ""
    role = config['iam_role']
    return f'''resource "google_project_iam_member" "{sink.tf_resource_name}_sink_writer" {{
  project = data.terraform_remote_state.project.outputs.project_id
  role    = "{role}"
  member  = google_logging_organization_sink.{sink.tf_resource_name}_sink.writer_identity
}}\n\n'''

# CSV解析
def parse_sinks_from_csv(path: str) -> List[Sink]:
    sinks: List[Sink] = []
    if not os.path.exists(path):
        raise FileNotFoundError(f"CSVファイルが見つかりません: {path}")
    with open(path, mode='r', encoding='utf-8') as infile:
        reader = csv.DictReader(infile)
        for i, row in enumerate(reader, start=1):
            required = {'log_type','filter','destination_type','destination_parent','retention_days'}
            if not required.issubset(row.keys()):
                raise ValueError(f"必要な列が不足 (行 {i}): {row.keys()}")
            log_type = (row.get('log_type') or '').strip()
            filt = (row.get('filter') or '').strip()
            dest_type = (row.get('destination_type') or '').strip()
            parent = (row.get('destination_parent') or '').strip()
            retention = (row.get('retention_days') or '').strip()
            if not log_type or not filt or not dest_type or not parent or not retention:
                print(f"警告: 行 {i} をスキップ（不完全）: {row}")
                continue
            try:
                days = int(retention)
            except ValueError:
                print(f"警告: retention_daysが数値でない (行 {i}): {retention}")
                continue
            sinks.append(Sink(log_type, filt, dest_type, parent, days))
    return sinks

def build_file_content(body: str) -> str:
    if not body.strip():
        return ""
    header = "# --- このファイルはPythonスクリリプトによって自動生成されました ---\n"
    return (header + "\n" + body).rstrip() + "\n"

def main():
    sinks = parse_sinks_from_csv(INPUT_CSV_FILE)
    # 重複する宛先を排除するためにsetを使用
    datasets = list(set((s.destination_parent, s.retention_days) for s in sinks if s.destination_type.lower() == 'bigquery'))
    buckets = list(set((s.destination_parent, s.retention_days) for s in sinks if s.destination_type.lower() == 'cloud storage'))

    dest_body = generate_dataset_hcl(datasets) + generate_bucket_hcl(buckets)
    with open(OUTPUT_DEST_FILE, 'w', encoding='utf-8') as f:
        f.write(build_file_content(dest_body))

    sinks_body = "".join(generate_sink_hcl(s) for s in sinks)
    with open(OUTPUT_SINKS_FILE, 'w', encoding='utf-8') as f:
        f.write(build_file_content(sinks_body))

    iam_body = "".join(generate_iam_hcl(s) for s in sinks)
    with open(OUTPUT_IAM_FILE, 'w', encoding='utf-8') as f:
        f.write(build_file_content(iam_body))

    print(f"生成: {OUTPUT_DEST_FILE}, {OUTPUT_SINKS_FILE}, {OUTPUT_IAM_FILE}")

if __name__ == "__main__":
    main()
