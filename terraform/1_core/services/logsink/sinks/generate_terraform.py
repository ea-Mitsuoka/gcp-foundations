"""gcp_log_sink_config.csvから設定を読み込み、Terraformの.tfファイルを自動生成するスクリプト。

このスクリプトは、ログシンクの要件が記述されたCSVファイルを基に、
以下の3種類のTerraform構成ファイル（.tf）を生成します。
- ログの宛先となるリソース（BigQueryデータセット、GCSバケット）
- ログシンク自体のリソース
- ログシンクに必要なIAM権限
"""
import csv
import re
import os
from dataclasses import dataclass
from typing import List, Tuple

# --- 定数 ---
SCRIPT_DIR: str = os.path.dirname(os.path.abspath(__file__))
"""スクリプトが配置されているディレクトリの絶対パス。"""

INPUT_CSV_FILE: str = os.path.join(SCRIPT_DIR, 'gcp_log_sink_config.csv')
"""入力ファイル（シンク要件CSV）のパス。"""

OUTPUT_DEST_FILE: str = os.path.join(SCRIPT_DIR, 'destinations.tf')
"""出力ファイル（宛先リソース）のパス。"""

OUTPUT_SINKS_FILE: str = os.path.join(SCRIPT_DIR, 'sinks.tf')
"""出力ファイル（シンクリソース）のパス。"""

OUTPUT_IAM_FILE: str = os.path.join(SCRIPT_DIR, 'iam.tf')
"""出力ファイル（IAM権限）のパス。"""

DESTINATION_CONFIG: dict = {
    'bigquery': {
        'uri_template': "bigquery.googleapis.com/projects/${{data.terraform_remote_state.project.outputs.project_id}}/datasets/{parent}",
        'iam_role': "roles/bigquery.dataEditor",
    },
    'cloud storage': {
        'uri_template': "storage.googleapis.com/{parent}",
        'iam_role': "roles/storage.objectCreator",
    },
}
"""宛先の種類ごとのTerraform設定テンプレート。"""

@dataclass
class Sink:
    """CSVファイルの1行分のシンク設定を保持するデータクラス。

    Attributes:
        log_type (str): ログの種類（例: '管理アクティビティ監査ログ'）。
        filter (str): ログをフィルタリングするためのクエリ文字列。
        destination_type (str): 宛先の種類（'bigquery' または 'cloud storage'）。
        destination_parent (str): 宛先リソースの名前（データセット名やバケット名）。
        retention_days (int): ログの保持期間（日数）。
    """
    log_type: str
    filter: str
    destination_type: str
    destination_parent: str
    retention_days: int

    @property
    def tf_resource_name(self) -> str:
        """ログの種類をTerraformのリソース名として使える形式に変換します。

        日本語のログ種別を、英小文字とアンダースコアで構成される
        スネークケースの文字列に変換します。

        Returns:
            str: Terraformリソース名として整形された文字列。
        """
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

def generate_dataset_hcl(datasets: List[Tuple[str, int]]) -> str:
    """BigQueryデータセットを作成するためのTerraform HCL文字列を生成します。

    Args:
        datasets (List[Tuple[str, int]]): データセット名と保持期間（日）のタプルのリスト。

    Returns:
        str: 生成された `google_bigquery_dataset` リソースのHCL文字列。
    """
    parts = []
    for ds, days in sorted(datasets, key=lambda x: x[0]):
        expiration_ms = days * 24 * 60 * 60 * 1000
        parts.append(f'''resource "google_bigquery_dataset" "{ds}" {{
  project                      = data.terraform_remote_state.project.outputs.project_id
  dataset_id                   = "{ds}"
  location                     = var.region
  delete_contents_on_destroy   = var.bq_dataset_delete_contents_on_destroy
  default_table_expiration_ms = {expiration_ms}

  labels = {{
    purpose = "log-sink-destination"
  }}
}}\n\n''')
    return "".join(parts)

def generate_bucket_hcl(buckets: List[Tuple[str, int]]) -> str:
    """GCSバケットを作成するためのTerraform HCL文字列を生成します。

    Args:
        buckets (List[Tuple[str, int]]): バケット名と保持期間（日）のタプルのリスト。

    Returns:
        str: 生成された `google_storage_bucket` リソースのHCL文字列。
    """
    parts = []
    for bkt, days in sorted(buckets, key=lambda x: x[0]):
        resource_name = re.sub(r'[^a-zA-Z0-9_]', '_', bkt).lower()
        parts.append(f'''resource "google_storage_bucket" "{resource_name}" {{
  project                     = data.terraform_remote_state.project.outputs.project_id
  name                        = "{bkt}"
  location                    = var.region
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

def generate_sink_hcl(sink: Sink) -> str:
    """ログシンクを作成するためのTerraform HCL文字列を生成します。

    Args:
        sink (Sink): 1つのシンク設定を表すSinkオブジェクト。

    Returns:
        str: 生成された `google_logging_organization_sink` リソースのHCL文字列。
    """
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
    return f'''resource "google_logging_organization_sink" "{sink.tf_resource_name}_sink" {{
  provider    = google-beta
  name        = "org-{sink.tf_resource_name}-sink"
  org_id      = data.external.org_id.result.organization_id
  filter      = "{escaped_filter}"
  destination = "{destination_uri}"{bigquery_options_block}
}}\n\n'''

def generate_iam_hcl(sink: Sink) -> str:
    """ログシンクに必要なIAM権限を付与するためのTerraform HCL文字列を生成します。

    Args:
        sink (Sink): 1つのシンク設定を表すSinkオブジェクト。

    Returns:
        str: 生成された `google_project_iam_member` リソースのHCL文字列。
    """
    config = DESTINATION_CONFIG.get(sink.destination_type.lower())
    if not config:
        return ""
    role = config['iam_role']
    return f'''resource "google_project_iam_member" "{sink.tf_resource_name}_sink_writer" {{
  project = data.terraform_remote_state.project.outputs.project_id
  role    = "{role}"
  member  = google_logging_organization_sink.{sink.tf_resource_name}_sink.writer_identity
}}\n\n'''

def parse_sinks_from_csv(path: str) -> List[Sink]:
    """gcp_log_sink_config.csvファイルを解析し、Sinkオブジェクトのリストを返します。

    Args:
        path (str): CSVファイルのパス。

    Returns:
        List[Sink]: CSVの各行から生成されたSinkオブジェクトのリスト。

    Raises:
        FileNotFoundError: 指定されたパスにCSVファイルが見つからない場合。
        ValueError: CSVのヘッダーに必要な列が不足している場合。
    """
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
    """HCL文字列の先頭に自動生成されたことを示すヘッダーを追加します。

    Args:
        body (str): メインとなるHCLコンテンツ文字列。

    Returns:
        str: ヘッダーが追加された最終的なファイルコンテンツ文字列。
    """
    if not body.strip():
        return ""
    header = "# --- このファイルはPythonスクリプトによって自動生成されました ---\n"
    return (header + "\n" + body).rstrip() + "\n"

def main():
    """スクリプトのメイン処理。

    CSVファイルを読み込み、解析し、複数の.tfファイルを生成・出力します。
    """
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
