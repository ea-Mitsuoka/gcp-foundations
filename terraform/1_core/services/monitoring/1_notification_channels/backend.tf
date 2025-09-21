terraform {
  backend "gcs" {
    prefix = "core/services/monitoring/1_notification_channels"
  }
}