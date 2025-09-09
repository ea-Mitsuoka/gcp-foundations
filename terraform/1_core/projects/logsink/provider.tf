provider "google" {
  // この設定により、Terraform実行時に自動でSAを借用します
  impersonate_service_account = var.terraform_service_account_email
}
