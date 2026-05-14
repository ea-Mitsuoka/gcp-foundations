# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

locals {
  alert_definitions     = csvdecode(file(var.alert_definitions_csv_path))
  alert_definitions_map = { for d in local.alert_definitions : d.alert_name => d }
  notifications         = csvdecode(file(var.notifications_csv_path))
  # 有効な通知設定のみをフィルタリング
  active_notifications = [for r in local.notifications : r if lower(r.receive_alerts) == "true"]
  # アラート名で通知メールをグループ化
  notifications_by_alert = {
    for row in local.active_notifications : row.alert_name => row.user_email...
  }
}

# 新しいモジュールを呼び出し、アラートを logsink プロジェクトに作成
module "log_match_alerts" {
  for_each = local.alert_definitions_map

  source = "../../../../../modules/log-match-alert-factory"

  scoping_project_id   = data.terraform_remote_state.monitoring_project.outputs.project_id
  monitored_project_id = "Organization-Wide"
  display_name         = each.value.alert_display_name
  filter               = each.value.metric_filter
  documentation        = each.value.alert_documentation

  # 第1段階で作成した通知チャネルを参照
  notification_channel_ids = [
    for email in lookup(local.notifications_by_alert, each.key, []) :
    data.terraform_remote_state.stage1_notification_channels.outputs.notification_channels_by_email[email].id
  ]
}