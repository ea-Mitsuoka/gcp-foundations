locals {
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

  # 4. CSVからBigQueryデータセットのリストを動的に抽出し、重複を排除
  unique_bigquery_datasets = {
    for sink in local.sinks_from_csv :
    sink.destination_parent => {
      retention_days = tonumber(sink.retention_days)
    }
    if lower(sink.destination_type) == "bigquery"
  }

  # 5. CSVからGCSバケットのリストを動的に抽出し、重複を排除
  unique_gcs_buckets = {
    for sink in local.sinks_from_csv :
    sink.destination_parent => {
      retention_days = tonumber(sink.retention_days)
    }
    if lower(sink.destination_type) == "cloud storage"
  }
}
