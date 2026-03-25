variable "scoping_project_id" {
  type        = string
  description = "アラートポリシーを作成するモニタリングプロジェクトのID。（メトリクススコーププロジェクト）"
}
variable "monitored_project_id" {
  type        = string
  description = "監視対象となるリソースが存在するGCPプロジェクトのID。"
}
variable "alert_display_name" {
  type        = string
  description = "Cloud Monitoringでのアラートポリシーの表示名。"
}
variable "alert_documentation" {
  type        = string
  description = "アラート発生時に通知されるメッセージに含めるドキュメント。Markdown形式で記述可能。"
}
variable "metric_type" {
  type        = string
  description = "アラートをトリガーするCloud Monitoringメトリックのタイプ。（例: 'logging.googleapis.com/log_entry_count'）"
}
variable "notification_channel_ids" {
  type        = list(string)
  default     = []
  description = "アラート通知を送信するCloud Monitoring通知チャネルのIDリスト。"
}
