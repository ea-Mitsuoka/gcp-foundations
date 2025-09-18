locals {
  alert_definitions = csvdecode(file(var.alert_definitions_csv_path))
}

module "log_metrics" {
  for_each = { for ad in local.alert_definitions : ad.alert_name => ad }

  source = "../../../../modules/log-metric-factory"

  project_id    = data.terraform_remote_state.logsink_project.outputs.project_id
  metric_name   = each.value.metric_name
  metric_filter = each.value.metric_filter
}
