# アラートを作成する monitoring プロジェクト
data "terraform_remote_state" "monitoring_project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/monitoring"
  }
}

# 監視対象の logsink プロジェクト
data "terraform_remote_state" "logsink_project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/logsink"
  }
}

# 通知チャネルの情報
data "terraform_remote_state" "stage1_notification_channels" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/services/monitoring/1_notification_channels"
  }
}