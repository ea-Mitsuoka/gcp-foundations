# --------------------------------------------------------------------------------
# Unit tests for monitoring-alert-policy module
# --------------------------------------------------------------------------------

mock_provider "google" {}

variables {
  scoping_project_id       = "monitoring-proj-123"
  monitored_project_id     = "target-proj-456"
  alert_display_name       = "High Error Rate"
  alert_documentation      = "Please check the logs."
  metric_type              = "logging.googleapis.com/user/test_metric"
  notification_channel_ids = ["projects/monitoring-proj-123/notificationChannels/1111"]
}

run "create_alert_policy" {
  command = plan

  assert {
    condition     = google_monitoring_alert_policy.this.project == "monitoring-proj-123"
    error_message = "Project ID does not match expected value"
  }

  assert {
    condition     = google_monitoring_alert_policy.this.display_name == "[target-proj-456] High Error Rate"
    error_message = "Display name does not match expected value"
  }

  assert {
    condition     = contains(google_monitoring_alert_policy.this.notification_channels, "projects/monitoring-proj-123/notificationChannels/1111")
    error_message = "Notification channel does not match expected value"
  }

  assert {
    condition     = google_monitoring_alert_policy.this.documentation[0].content == "Please check the logs."
    error_message = "Documentation content does not match expected value"
  }
}
