provider "google" {
  # サービスアカウントを借用して操作を実行
  impersonate_service_account = var.terraform_service_account_email
  region                      = var.gcp_region
}

provider "google-beta" {
  impersonate_service_account = var.terraform_service_account_email
  region                      = var.gcp_region
}