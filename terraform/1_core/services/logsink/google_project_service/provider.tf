provider "google" {
  impersonate_service_account = var.terraform_service_account_email
  project                     = var.project_id
  region                      = var.gcp_region
}

provider "google-beta" {
  impersonate_service_account = var.terraform_service_account_email
  project                     = var.project_id
  region                      = var.gcp_region
}
