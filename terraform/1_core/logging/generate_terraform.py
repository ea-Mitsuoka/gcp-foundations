import csv
import re
import os
from dataclasses import dataclass
from typing import List, Dict, Set

# --- 定数定義 ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_CSV_FILE = os.path.join(SCRIPT_DIR, 'sinks.csv')
OUTPUT_DEST_FILE = os.path.join(SCRIPT_DIR, 'destinations.tf')
OUTPUT_SINKS_FILE = os.path.join(SCRIPT_DIR, 'sinks.tf')
OUTPUT_IAM_FILE = os.path.join(SCRIPT_DIR, 'iam.tf')

# シンク先タイプごとの設定を一元管理
DESTINATION_CONFIG = {
    'bigquery': {
        'uri_template': "bigquery.googleapis.com/projects/${{var.project_id}}/datasets/{parent}",
        'iam_role': "roles/bigquery.dataEditor",
    },
    'cloud storage': {
        'uri_template': "storage.googleapis.com/{parent}",
        'iam_role': "roles/storage.objectCreator",
    },
}

# --- データクラス定義 ---
@dataclass
class Sink:
    """CSVの1行を表すデータクラス"""
    log_type: str
    filter: str
    destination_type: str
    destination_parent: str
    # ★ 修正点1: destination_child フィールドを削除

    @property
    def tf_resource_name(self) -> str:
        """Terraformリソース名を生成する"""
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
            # 必要に応じて他のマッピングも追加
        }
        name = translation_map.get(self.log_type, self.log_type)
        s = re.sub(r'[^a-zA-Z0-9_ ]', '', name).strip().lower()
        return re.sub(r'\s+', '_', s)

# --- HCL生成関数 ---
def generate_dataset_hcl(datasets: Set[str]) -> str:
    """BigQueryデータセットのHCLを生成する"""
    parts = []
    for ds in sorted(list(datasets)):
        parts.append(f"""resource "google_bigquery_dataset" "{ds}" {{
  project                     = var.project_id
  dataset_id                  = "{ds}"
  location                    = var.region
  delete_contents_on_destroy  = var.bq_dataset_delete_contents_on_destroy

  labels = {{
    purpose = "log-sink-destination"
  }}
}}\n\n""")
    return "".join(parts)

def generate_bucket_hcl(buckets: Set[str]) -> str:
    """Cloud StorageバケットのHCLを生成する"""
    parts = []
    for bkt in sorted(list(buckets)):
        resource_name = re.sub(r'[^a-zA-Z0-9_]', '_', bkt).lower()
        parts.append(f"""resource "google_storage_bucket" "{resource_name}" {{
  project                   = var.project_id
  name                      = "{bkt}"
  location                  = var.region
  uniform_bucket_level_access = true

  lifecycle_rule {{
    action {{
      type = "Delete"
    }}
    condition {{
      age = var.gcs_log_retention_days
    }}
  }}

  versioning {{
    enabled = true
  }}
}}\n\n""")
    return "".join(parts)

def generate_sink_hcl(sink: Sink) -> str:
    """単一のログシンクのHCLを生成する（sink 本体のみ）"""
    config = DESTINATION_CONFIG.get(sink.destination_type.lower())
    if not config:
        return ""

    destination_uri = config['uri_template'].format(parent=sink.destination_parent)
    escaped_filter = sink.filter.replace('"', '\\"')

    bigquery_options_block = ""
    if sink.destination_type.lower() == 'bigquery':
        bigquery_options_block = """
  bigquery_options {
    use_partitioned_tables = true
  }"""

    sink_block = f"""resource "google_organization_log_sink" "{sink.tf_resource_name}_sink" {{
  name                 = "org-{sink.tf_resource_name}-sink"
  org_id               = var.organization_id
  filter               = "{escaped_filter}"
  destination          = "{destination_uri}"
  unique_writer_identity = true{bigquery_options_block}
}}\n\n"""
    return sink_block

def generate_iam_hcl(sink: Sink) -> str:
    """単一のIAMバインディングのHCLを生成する（sink 用サービスアカウントへの付与）"""
    config = DESTINATION_CONFIG.get(sink.destination_type.lower())
    if not config:
        return ""
    iam_role = config['iam_role']
    iam_block = f"""resource "google_project_iam_member" "{sink.tf_resource_name}_sink_writer" {{
  project = var.project_id
  role    = "{iam_role}"
  member  = google_organization_log_sink.{sink.tf_resource_name}_sink.writer_identity
}}\n\n"""
    return iam_block

def parse_sinks_from_csv(path: str) -> List[Sink]:
    """CSVを読み込み、Sinkオブジェクトのリストを返す"""
    sinks: List[Sink] = []
    if not os.path.exists(path):
        raise FileNotFoundError(f"CSVファイルが見つかりません: {path}")

    with open(path, mode='r', encoding='utf-8') as infile:
        reader = csv.DictReader(infile)
        for i, row in enumerate(reader, start=1):
            # 必要なカラムがあるかチェック
            if not {'log_type', 'filter', 'destination_type', 'destination_parent'}.issubset(row.keys()):
                raise ValueError(f"CSVに必要な列がありません (行 {i}): {row.keys()}")

            log_type = (row.get('log_type') or '').strip()
            filt = (row.get('filter') or '').strip()
            dest_type = (row.get('destination_type') or '').strip()
            dest_parent = (row.get('destination_parent') or '').strip()

            if not log_type or not dest_type or not dest_parent:
                # 空行や不完全な行はスキップ
                print(f"警告: CSVの行 {i} をスキップします（不完全）: {row}")
                continue

            sinks.append(Sink(
                log_type=log_type,
                filter=filt,
                destination_type=dest_type,
                destination_parent=dest_parent,
            ))
    return sinks

# --- メイン処理 ---
def main():
    """スクリプトのメイン処理（出力を3ファイルに分割）"""
    sinks = parse_sinks_from_csv(INPUT_CSV_FILE)

    datasets = {s.destination_parent for s in sinks if s.destination_type.lower() == 'bigquery'}
    buckets = {s.destination_parent for s in sinks if s.destination_type.lower() == 'cloud storage'}

    # ヘッダは1行改行のみ
    header = "# --- このファイルはPythonスクリプトによって自動生成されました ---\n"

    # destinations (datasets + buckets)
    dest_body = generate_dataset_hcl(datasets) + generate_bucket_hcl(buckets)
    dest_content = (header + dest_body).rstrip() + "\n"
    with open(OUTPUT_DEST_FILE, 'w', encoding='utf-8') as f:
        f.write(dest_content)

    # sinks (organization_log_sink)
    sinks_body = "".join([generate_sink_hcl(s) for s in sinks])
    sinks_content = (header + sinks_body).rstrip() + "\n"
    with open(OUTPUT_SINKS_FILE, 'w', encoding='utf-8') as f:
        f.write(sinks_content)

    # iam bindings
    iam_body = "".join([generate_iam_hcl(s) for s in sinks])
    iam_content = (header + iam_body).rstrip() + "\n"
    with open(OUTPUT_IAM_FILE, 'w', encoding='utf-8') as f:
        f.write(iam_content)

    print(f"生成: {OUTPUT_DEST_FILE}, {OUTPUT_SINKS_FILE}, {OUTPUT_IAM_FILE}")

if __name__ == "__main__":
    main()
