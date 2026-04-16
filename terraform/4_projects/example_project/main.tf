data "google_organization" "org" {
  domain = var.organization_domain
}

module "project" {
  source = "../../modules/project-factory"

  project_id      = "${var.project_id_prefix}-${var.environment}-${var.app_name}"
  name            = "${var.app_name}-${var.environment}"
  organization_id = data.google_organization.org.org_id
  folder_id       = var.folder_id != "" ? var.folder_id : null
  labels          = var.labels

  # 課金アカウントの紐付けは別途管理者が実行するため、Terraform では設定しない
}

module "project_services" {
  source = "../../modules/project-services"

  project_id   = module.project.project_id
  project_apis = var.billing_linked ? var.project_apis : toset([])
}
