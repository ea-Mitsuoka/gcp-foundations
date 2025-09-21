# 他のディレクトリから参照できるように、作成したチャネルの情報を出力
output "notification_channels_by_email" {
  description = "A map of notification channels keyed by email address."
  value = {
    for channel in google_monitoring_notification_channel.email :
    channel.labels.email_address => channel
  }
}
