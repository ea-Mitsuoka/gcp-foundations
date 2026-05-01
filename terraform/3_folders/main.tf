resource "terraform_data" "variable_validation" {
  input = [
    var.enable_org_policies,
    var.enable_tags,
    data.terraform_remote_state.organization
  ]
}

data "terraform_remote_state" "organization" {
  count   = var.enable_org_policies || var.enable_tags ? 1 : 0
  backend = "gcs"
  config = {
    bucket                      = var.gcs_backend_bucket
    prefix                      = "organization"
    impersonate_service_account = var.terraform_service_account_email
  }
}
