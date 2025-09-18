data "terraform_remote_state" "monitoring_project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/monitoring"
  }
}

# ◀◀ NEW: logsink/log_based_metrics で作成された指標の情報をtfstateから参照
data "terraform_remote_state" "log_metrics_state" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/services/logsink/log_based_metrics"
  }
}