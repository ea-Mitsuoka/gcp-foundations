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

resource "google_project_service" "apis" {
  for_each = var.project_apis

  project                    = module.project.project_id
  service                    = each.key
  disable_dependent_services = true
}
