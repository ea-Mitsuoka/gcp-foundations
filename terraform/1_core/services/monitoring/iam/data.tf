data "terraform_remote_state" "project" {
  backend = "gcs"
  config = {
    bucket = local.gcs_backend_bucket
    prefix = "core/projects/monitoring"
  }
}
