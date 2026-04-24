# --------------------------------------------------------------------------------
# Unit tests for log-match-alert-factory module
# --------------------------------------------------------------------------------

mock_provider "google" {}

variables {
  scoping_project_id       = "monitoring-proj-123"
  monitored_project_id     = "target-proj-456"
  display_name             = "Log Match Alert"
  filter                   = "severity>=ERROR"
  documentation            = "Check the error logs."
  notification_channel_ids = ["projects/monitoring-proj-123/notificationChannels/2222"]
}

run "create_log_match_alert" {
  command = plan

  assert {
    condition     = google_monitoring_alert_policy.this.project == "monitoring-proj-123"
    error_message = "Project ID does not match expected value"
  }

  assert {
    condition     = google_monitoring_alert_policy.this.display_name == "[target-proj-456] Log Match Alert"
    error_message = "Display name does not match expected value"
  }

  assert {
    condition     = google_monitoring_alert_policy.this.conditions[0].condition_matched_log[0].filter == "severity>=ERROR"
    error_message = "Log match filter does not match expected value"
  }

  assert {
    condition     = contains(google_monitoring_alert_policy.this.notification_channels, "projects/monitoring-proj-123/notificationChannels/2222")
    error_message = "Notification channel does not match expected value"
  }

  assert {
    condition     = google_monitoring_alert_policy.this.documentation[0].content == "Check the error logs."
    error_message = "Documentation content does not match expected value"
  }
}
