# terraform/modules/monitoring-alert-policy/main.tf
resource "google_monitoring_alert_policy" "this" {
  project      = var.scoping_project_id
  display_name = "[${var.monitored_project_id}] ${var.alert_display_name}"
  combiner     = "OR"

  conditions {
    display_name = "Log-based metric triggered for ${var.monitored_project_id}"
    condition_threshold {
      filter          = "metric.type=\"${var.metric_type}\" AND resource.labels.project_id=\"${var.monitored_project_id}\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      trigger { count = 1 }
    }
  }

  notification_channels = var.notification_channel_ids
  documentation {
    content   = var.alert_documentation
    mime_type = "text/markdown"
  }
}
