data "google_organization" "org" {
  domain = var.organization_domain
}

data "terraform_remote_state" "folders" {
  backend = "gcs"
  config = {
    bucket                      = var.gcs_backend_bucket
    prefix                      = "folders"
    impersonate_service_account = var.terraform_service_account_email
  }
}

data "terraform_remote_state" "organization" {
  count   = var.vpc_sc ? 1 : 0
  backend = "gcs"
  config = {
    bucket                      = var.gcs_backend_bucket
    prefix                      = "organization"
    impersonate_service_account = var.terraform_service_account_email
  }
}

data "terraform_remote_state" "vpc_host" {
  count   = var.enable_shared_vpc && var.shared_vpc_env != "none" ? 1 : 0
  backend = "gcs"
  config = {
    bucket                      = var.gcs_backend_bucket
    prefix                      = "core/base/vpc-host"
    impersonate_service_account = var.terraform_service_account_email
  }
}

locals {
  host_project_id    = var.shared_vpc_env == "prod" ? try(data.terraform_remote_state.vpc_host[0].outputs.prod_host_project_id, null) : (var.shared_vpc_env == "dev" ? try(data.terraform_remote_state.vpc_host[0].outputs.dev_host_project_id, null) : null)
  resolved_folder_id = var.folder_id != "" ? try(data.terraform_remote_state.folders.outputs[format("%s_folder_id", var.folder_id)], var.folder_id) : null
}

module "project" {
  source = "../../modules/project-factory"

  project_id      = "${var.project_id_prefix}-${var.app_name}"
  name            = "${var.app_name}-${var.environment}"
  organization_id = data.google_organization.org.org_id
  folder_id       = local.resolved_folder_id
  labels          = var.labels


  # 課金アカウントの紐付けは別途管理者が実行するため、Terraform では設定しない
}

module "project_services" {
  source = "../../modules/project-services"

  project_id   = module.project.project_id
  project_apis = var.billing_linked ? var.project_apis : toset([])
}

resource "google_compute_shared_vpc_service_project" "service_project" {
  count           = var.billing_linked && var.enable_shared_vpc && var.shared_vpc_env != "none" && local.host_project_id != null ? 1 : 0
  host_project    = local.host_project_id
  service_project = module.project.project_id

  depends_on = [module.project_services]
}

resource "google_access_context_manager_service_perimeter_resource" "service_perimeter_resource" {
  count          = var.vpc_sc && try(data.terraform_remote_state.organization[0].outputs.service_perimeter_name, null) != null ? 1 : 0
  perimeter_name = data.terraform_remote_state.organization[0].outputs.service_perimeter_name
  resource       = "projects/${module.project.project_number}"

  depends_on = [module.project]
}
