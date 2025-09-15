locals {
  # providerが依存するデフォルトリージョンを定義
  default_region = "asia-northeast1"

  # 1. CSVファイルを読み込み、オブジェクトのリストに変換
  sinks_from_csv = csvdecode(file("${path.module}/gcp_log_sink_config.csv"))

  # 2. Pythonの translation_map に相当するマップを定義
  log_type_translation_map = {
    "管理アクティビティ監査ログ" = "admin_activity_audit_logs",
    "データアクセス監査ログ"   = "data_access_audit_logs",
    "セキュリティ監査ログ"    = "security_audit_logs",
    "アクセスログ"        = "access_logs",
    "VPCフローログ"      = "vpc_flow_logs",
    "エラーログ"         = "error_logs",
    "システムイベントログ"    = "system_event_logs",
    "ポリシー違反ログ"      = "policy_violation_logs",
    "課金ログ"          = "billing_logs",
    "カスタムログ"        = "custom_logs",
  }

  # 3. for_eachで使いやすいように、CSVデータをシンク設定のマップに変換
  #    キーには、変換マップを使って日本語から変換したリソース名を使用
  sink_configs = {
    for sink in local.sinks_from_csv :
    # lookup関数で変換マップを検索し、見つからなければ元の名前をスネークケース化
    lookup(local.log_type_translation_map, sink.log_type, lower(replace(sink.log_type, " ", "_"))) => {
      filter             = sink.filter
      destination_type   = sink.destination_type
      destination_parent = sink.destination_parent
    }
  }

  # --- ▼▼▼ ここからが修正箇所 ▼▼▼ ---

  # 4a. BigQuery宛先の保持期間を宛先名でグループ化
  grouped_bigquery_retention_days = {
    for sink in local.sinks_from_csv :
    sink.destination_parent => tonumber(sink.retention_days)... # Correct syntax: ... is before if
    if lower(sink.destination_type) == "bigquery"
  }

  # 4b. グループ化したリストの中から、宛先ごとに最大の保持期間を選択
  unique_bigquery_datasets = {
    for ds_name, retention_days_list in local.grouped_bigquery_retention_days :
    ds_name => {
      retention_days = max(retention_days_list...)
    }
  }

  # 5a. GCS宛先の保持期間を宛先名でグループ化
  grouped_gcs_retention_days = {
    for sink in local.sinks_from_csv :
    sink.destination_parent => tonumber(sink.retention_days)... # Correct syntax: ... is before if
    if lower(sink.destination_type) == "cloud storage"
  }

  # 5b. グループ化したリストの中から、宛先ごとに最大の保持期間を選択
  unique_gcs_buckets = {
    for bucket_name, retention_days_list in local.grouped_gcs_retention_days :
    bucket_name => {
      retention_days = max(retention_days_list...)
    }
  }
}
