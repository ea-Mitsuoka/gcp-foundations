# project-iamモジュールを呼び出して、上記のロールを付与する
module "impersonated_sa_permissions" {
  source = "../../../modules/project-iam"

  project_id = module.logsink_project.project_id
  member     = "serviceAccount:${var.terraform_service_account_email}"
  roles      = var.roles
}
