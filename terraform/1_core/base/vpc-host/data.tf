data "google_organization" "org" {
  domain = var.organization_domain
}

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket                      = var.gcs_backend_bucket
    prefix                      = "bootstrap"
    impersonate_service_account = var.terraform_service_account_email
  }
}
