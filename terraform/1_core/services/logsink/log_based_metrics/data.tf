data "terraform_remote_state" "project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/logsink"
  }
}
