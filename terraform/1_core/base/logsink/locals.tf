locals {
  # プロジェクトレベルで必要なIAMロールのリスト
  logsink_project_base_roles = [
    "roles/viewer",            # リソースの読み取り権限 (基本)
    "roles/bigquery.admin",    # BigQueryデータセットの管理権限
    "roles/storage.admin",     # GCSバケットの管理権限
    "roles/logging.admin",     # ログ関連の管理権限
    "roles/iam.securityAdmin", # IAMポリシーの管理権限
  ]
  # このステージのデフォルトリージョンを「共有メモ」として定義
  default_region = "asia-northeast1"
}
