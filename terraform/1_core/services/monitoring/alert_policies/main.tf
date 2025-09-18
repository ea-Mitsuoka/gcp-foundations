# (google_monitoring_notification_channel リソースは変更なし)
resource "google_monitoring_notification_channel" "email" {
  for_each = local.unique_emails_to_notify
  project      = data.terraform_remote_state.monitoring_project.outputs.project_id
  display_name = "Email Channel for ${each.key}"
  type         = "email"
  labels = {
    email_address = each.key
  }
}

module "project_alerts" {
  for_each = local.alert_subscriptions

  source = "../../../../modules/monitoring-alert-policy"

  scoping_project_id    = data.terraform_remote_state.monitoring_project.outputs.project_id
  monitored_project_id  = each.value.monitored_project_id
  alert_display_name    = each.value.alert_display_name
  alert_documentation   = each.value.alert_documentation
  metric_type           = each.value.metric_type
  notification_channel_ids = [
    for email in each.value.notification_emails : google_monitoring_notification_channel.email[email].id
  ]
}
