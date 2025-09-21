resource "google_monitoring_alert_policy" "this" {
  project      = var.project_id
  display_name = "[${var.project_id}] ${var.display_name}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Log match condition for ${var.display_name}"

    condition_matched_log {
      filter = var.filter
    }
  }

  alert_strategy {
    notification_rate_limit {
      # 5分 (300秒) に1回まで通知を制限
      period = "300s"
    }
  }

  notification_channels = var.notification_channel_ids

  documentation {
    content   = var.documentation
    mime_type = "text/markdown"
  }
}