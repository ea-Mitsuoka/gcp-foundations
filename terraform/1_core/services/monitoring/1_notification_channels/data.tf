data "terraform_remote_state" "monitoring_project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/monitoring"
  }
}
