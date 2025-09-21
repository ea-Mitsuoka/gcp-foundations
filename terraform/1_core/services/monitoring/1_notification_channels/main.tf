# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# set-gcs-bucket-value.sh .
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

# localsブロックで通知対象のメールアドレスを定義
locals {
  notifications = csvdecode(file(var.notifications_csv_path))
  # receive_alertsがtrueの通知設定のみをフィルタリング
  active_notifications = [for r in local.notifications : r if lower(r.receive_alerts) == "true"]
  # 通知先のメールアドレスを重複なくリスト化
  unique_emails_to_notify = toset([for r in local.active_notifications : r.user_email])
}

# 通知チャネルを monitoring プロジェクトに作成
resource "google_monitoring_notification_channel" "email" {
  for_each     = local.unique_emails_to_notify
  project      = data.terraform_remote_state.monitoring_project.outputs.project_id
  display_name = "Email Channel for ${each.key}"
  type         = "email"
  labels       = { email_address = each.key }
}
