# 先にservices/logsink/datasetsでapplyをして適用しておくこと
# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# set-gcs-bucket-value.sh .
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

locals {
  monitoring_project_id = data.terraform_remote_state.monitoring_project.outputs.project_id
  logsink_project_id    = data.terraform_remote_state.logsink_project.outputs.project_id
  logs_dataset_id       = data.terraform_remote_state.logsink_sinks.outputs.admin_activity_dataset_id
}

resource "google_bigquery_table" "inactive_users_view" {
  project             = data.terraform_remote_state.analytics_dataset.outputs.analytics_dataset_project
  dataset_id          = data.terraform_remote_state.analytics_dataset.outputs.analytics_dataset_id
  table_id            = "inactive_users_view"
  deletion_protection = false

  view {
    query = replace(
      replace(
        file("${path.module}/inactive_users_view.sql"),
        "__LOGSINK_PROJECT_ID__",
        local.logsink_project_id
      ),
      "__LOGS_DATASET_ID__",
      local.logs_dataset_id
    )
    use_legacy_sql = false
  }
}

# Cloud Functionをデプロイ
resource "google_cloudfunctions2_function" "inactive_account_reporter" {
  project  = local.monitoring_project_id
  name     = "inactive-account-reporter"
  location = var.gcp_region

  build_config {
    runtime     = "python311"
    entry_point = "check_inactive_accounts"
    source {
      storage_source {
        bucket = data.terraform_remote_state.bootstrap.outputs.function_source_bucket_name
        object = var.function_source_object
      }
    }
  }

  service_config {
    max_instance_count    = 1
    min_instance_count    = 0
    available_memory      = "256Mi"
    timeout_seconds       = 300
    service_account_email = google_service_account.inactive_check_sa.email
    environment_variables = {
      LOGSINK_PROJECT_ID    = local.logsink_project_id
      MONITORING_PROJECT_ID = local.monitoring_project_id
    }
  }
}

# 毎日午前3時にFunctionを実行するスケジューラ
resource "google_cloud_scheduler_job" "inactive_check_scheduler" {
  project     = local.monitoring_project_id
  name        = "daily-inactive-account-check"
  description = "毎日午前3時にinactive-account-reporter関数をトリガーし、90日以上活動のないGCPユーザーアカウントを検知します。"
  schedule    = "0 3 * * *"
  time_zone   = "Asia/Tokyo"

  http_target {
    uri         = google_cloudfunctions2_function.inactive_account_reporter.service_config[0].uri
    http_method = "POST"
    # oauth_token から oidc_token に変更
    oidc_token {
      service_account_email = google_service_account.inactive_check_sa.email
      # audience は通常、呼び出し先のURIと同じものを指定します
      audience = google_cloudfunctions2_function.inactive_account_reporter.service_config[0].uri
    }
  }
}


# カスタム指標を監視するアラートポリシー
resource "google_monitoring_alert_policy" "inactive_account_alert" {
  project      = local.monitoring_project_id
  display_name = "Inactive User Account Detected"
  combiner     = "OR"

  notification_channels = [for channel in values(data.terraform_remote_state.notification_channels.outputs.notification_channels_by_email) : channel.id]

  conditions {
    display_name = "Count of inactive accounts is greater than 0"
    condition_threshold {
      filter          = "metric.type=\"custom.googleapis.com/security/inactive_account_count\" AND resource.type=\"global\""
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      trigger { count = 1 }
    }
  }

  documentation {
    content   = "One or more user accounts with IAM permissions have shown no activity for over 90 days. Please investigate and disable or remove unnecessary accounts. Check the `inactive_users_view` in the `security_analytics` dataset of the logsink project for details."
    mime_type = "text/markdown"
  }
}
