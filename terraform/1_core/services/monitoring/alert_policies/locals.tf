locals {
  alert_definitions_map   = { for d in csvdecode(file(var.alert_definitions_csv_path)) : d.alert_name => d }
  notifications           = csvdecode(file(var.notifications_csv_path))
  active_notifications    = [for r in local.notifications : r if lower(r.receive_alerts) == "true"]
  unique_emails_to_notify = toset([for r in local.active_notifications : r.user_email])

  alert_subscriptions = {
    for row in local.active_notifications :
    "${row.project_id}:${row.alert_name}" => {
      monitored_project_id  = row.project_id,
      alert_display_name    = local.alert_definitions_map[row.alert_name].alert_display_name,
      alert_documentation   = local.alert_definitions_map[row.alert_name].alert_documentation,
      # ◀◀ tfstateから取得したメトリックのTypeを結合
      metric_type           = data.terraform_remote_state.log_metrics_state.outputs.log_metrics[row.alert_name].type,
      notification_emails = [
        for r in local.active_notifications : r.user_email
        if r.project_id == row.project_id && r.alert_name == row.alert_name
      ]
    }
  }
}