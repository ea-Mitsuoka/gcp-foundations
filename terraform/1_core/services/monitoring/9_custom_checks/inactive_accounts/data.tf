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

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "bootstrap"
  }
}

# monitoringプロジェクトのプロジェクト番号などを取得するためのデータソース
data "google_project" "monitoring" {
  project_id = data.terraform_remote_state.monitoring_project.outputs.project_id
}


data "terraform_remote_state" "logsink_sinks" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/services/logsink/sinks"
  }
}

# 新しく作成したdatasetsモジュールの状態を読み込む
data "terraform_remote_state" "analytics_dataset" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/services/logsink/datasets"
  }
}
