provider "google" {
  impersonate_service_account = var.terraform_service_account_email
}

provider "google-beta" {
  impersonate_service_account = var.terraform_service_account_email
}
