data "terraform_remote_state" "vpc_host" {
  backend = "gcs"
  config = {
    bucket                      = var.gcs_backend_bucket
    prefix                      = "core/base/vpc-host"
    impersonate_service_account = var.terraform_service_account_email
  }
}
