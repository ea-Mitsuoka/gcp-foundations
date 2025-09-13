module "bootstrap_iam" {
  source = "../../modules/project-iam"

  project_id = var.project_id
  member     = "serviceAccount:${var.terraform_service_account_email}"
  roles      = var.roles
}
