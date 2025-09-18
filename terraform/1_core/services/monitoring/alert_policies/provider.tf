provider "google" {
  impersonate_service_account = var.terraform_service_account_email
  project                     = data.terraform_remote_state.monitoring_project.outputs.project_id
}
provider "google-beta" {
  impersonate_service_account = var.terraform_service_account_email
  project                     = data.terraform_remote_state.monitoring_project.outputs.project_id
}