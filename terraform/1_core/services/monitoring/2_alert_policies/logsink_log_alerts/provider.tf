terraform {
  required_version = "~> 1.14"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.48.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.48.0"
    }
  }
}

provider "google" {
  # サービスアカウントを借用して操作を実行
  impersonate_service_account = var.terraform_service_account_email
  project                     = data.terraform_remote_state.monitoring_project.outputs.project_id
}

provider "google-beta" {
  impersonate_service_account = var.terraform_service_account_email
  project                     = data.terraform_remote_state.monitoring_project.outputs.project_id
}