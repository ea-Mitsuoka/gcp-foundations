module "monitoring_iam" {
  source = "../../../../modules/project-iam"

  project_id = data.terraform_remote_state.project.outputs.project_id
  member     = "serviceAccount:${var.terraform_service_account_email}"
  roles      = var.roles
}
