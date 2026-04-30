terraform {
  backend "gcs" {
    bucket = ""
    prefix = "core/services/monitoring/1_notification_channels"
  }
}