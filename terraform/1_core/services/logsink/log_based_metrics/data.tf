data "terraform_remote_state" "logsink_project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/logsink"
  }
}
