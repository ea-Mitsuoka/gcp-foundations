# 組織情報を取得
data "google_organization" "org" {
  domain = var.organization_domain # ルートのtfvarsから注入される想定
}

# monitoringプロジェクトの情報をリモートステートから取得
data "terraform_remote_state" "monitoring_project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/monitoring"
  }
}

# logsinkプロジェクトの情報をリモートステートから取得
data "terraform_remote_state" "logsink_project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/logsink"
  }
}

# 通知チャネルの情報をリモートステートから取得
data "terraform_remote_state" "notification_channels" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/services/monitoring/1_notification_channels"
  }
}
