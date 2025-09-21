terraform {
  backend "gcs" {
    prefix = "core/services/monitoring/2_alert_policies/logsink_log_alerts"
  }
}