resource "terraform_data" "variable_validation" {
  input = var.enable_org_policies
}

data "google_organization" "org" {
  domain = var.organization_domain
}
