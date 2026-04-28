provider "google" {
  impersonate_service_account = var.terraform_service_account_email
}

provider "google" {
  alias                       = "logsink"
  project                     = data.terraform_remote_state.project.outputs.project_id
  impersonate_service_account = var.terraform_service_account_email
}

provider "google-beta" {
  project                     = data.terraform_remote_state.project.outputs.project_id
  impersonate_service_account = var.terraform_service_account_email
}
