# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# set-gcs-bucket-value.sh .
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

locals {
  alert_definitions     = csvdecode(file(var.alert_definitions_csv_path))
  alert_definitions_map = { for d in local.alert_definitions : d.alert_name => d }
  notifications         = csvdecode(file(var.notifications_csv_path))
  active_notifications  = [for r in local.notifications : r if lower(r.receive_alerts) == "true" && r.project_id == data.terraform_remote_state.logsink_project.outputs.project_id]

  # 通知チャネルをメールアドレスでグループ化
  notification_channels_by_email = {
    for email in toset([for r in local.active_notifications : r.user_email]) :
    email => google_monitoring_notification_channel.email[email].id
  }

  # アラート名で通知設定をグループ化
  notifications_by_alert = {
    for row in local.active_notifications : row.alert_name => row.user_email...
  }
}

# 通知チャネルの作成はそのまま
resource "google_monitoring_notification_channel" "email" {
  for_each     = toset([for r in local.active_notifications : r.user_email])
  project      = data.terraform_remote_state.logsink_project.outputs.project_id
  display_name = "Email Channel for ${each.key}"
  type         = "email"
  labels       = { email_address = each.key }
}

# 新しいモジュールを呼び出す
module "log_match_alerts" {
  for_each = local.alert_definitions_map

  source = "../../../../modules/log-match-alert-factory"

  project_id    = data.terraform_remote_state.logsink_project.outputs.project_id
  display_name  = each.value.alert_display_name
  filter        = each.value.metric_filter # CSVのフィルタをそのまま使用
  documentation = each.value.alert_documentation

  # 対応する通知チャネルIDのリストを動的に作成
  notification_channel_ids = [
    for email in lookup(local.notifications_by_alert, each.key, []) :
    local.notification_channels_by_email[email]
  ]
}
