data "terraform_remote_state" "project" {
  backend = "gcs"
  config = {
    bucket = local.gcs_backend_bucket
    prefix = "core/projects/logsink"
  }
}

data "google_organization" "org" {
  domain = var.organization_domain
}
