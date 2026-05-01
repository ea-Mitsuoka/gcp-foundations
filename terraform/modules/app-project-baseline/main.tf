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
  count   = (var.enable_vpc_sc && var.vpc_sc != "" && var.vpc_sc != null) || var.enable_tags ? 1 : 0
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
  perimeter_id       = length(data.terraform_remote_state.organization) > 0 && var.vpc_sc != "" ? try(data.terraform_remote_state.organization[0].outputs.service_perimeter_ids[var.vpc_sc], null) : null
  subnet_id          = var.shared_vpc_subnet != "" ? try(data.terraform_remote_state.vpc_host[0].outputs.shared_vpc_subnet_ids[var.shared_vpc_subnet], null) : null
}


resource "terraform_data" "variable_validation" {
  input = {
    enable_org_policies = var.enable_org_policies
    central_monitoring  = var.central_monitoring
    central_logging     = var.central_logging
  }
}

module "project" {
  source = "../project-factory"

  project_id      = "${var.project_id_prefix}-${var.app_name}"
  name            = "${var.app_name}-${var.environment}"
  organization_id = data.google_organization.org.id
  folder_id       = local.resolved_folder_id
  labels = merge(var.labels, {
    monitoring = tostring(var.central_monitoring)
    logging    = tostring(var.central_logging)
  })
  deletion_protection   = var.deletion_protection
  budget_amount         = var.budget_amount
  budget_alert_emails   = var.budget_alert_emails
  billing_account       = var.billing_account_id
  monitoring_project_id = var.mgmt_project_id
}

resource "google_compute_shared_vpc_service_project" "service_project" {
  count           = var.enable_shared_vpc && var.shared_vpc_env != "none" && local.host_project_id != null ? 1 : 0
  host_project    = local.host_project_id
  service_project = module.project.project_id
}

resource "google_access_context_manager_service_perimeter_resource" "service_perimeter_resource" {
  count          = local.perimeter_id != null ? 1 : 0
  perimeter_name = local.perimeter_id
  resource       = "projects/${module.project.project_number}"
  depends_on     = [module.project]
}

resource "google_compute_subnetwork_iam_member" "subnet_user" {
  count      = local.subnet_id != null ? 1 : 0
  project    = local.host_project_id
  region     = try(element(split("/", local.subnet_id), 3), "asia-northeast1")
  subnetwork = local.subnet_id
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${module.project.project_number}@cloudservices.gserviceaccount.com"
}

# Compute Engine のデフォルトサービスアカウントにもサブネット利用権限を付与 (VM作成等の運用に必須)
resource "google_compute_subnetwork_iam_member" "subnet_user_compute" {
  count      = local.subnet_id != null ? 1 : 0
  project    = local.host_project_id
  region     = try(element(split("/", local.subnet_id), 3), "asia-northeast1")
  subnetwork = local.subnet_id
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${module.project.project_number}-compute@developer.gserviceaccount.com"
}

resource "google_tags_tag_binding" "project_tags" {
  for_each   = var.enable_tags && length(data.terraform_remote_state.organization) > 0 ? toset(var.org_tags) : []
  parent     = "//cloudresourcemanager.googleapis.com/projects/${module.project.project_number}"
  tag_value  = data.terraform_remote_state.organization[0].outputs.tag_value_ids[each.key]
  depends_on = [module.project]
}
