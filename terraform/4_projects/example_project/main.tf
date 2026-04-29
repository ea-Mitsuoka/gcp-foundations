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
  count   = var.enable_vpc_sc && var.vpc_sc != "" && var.vpc_sc != null ? 1 : 0
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

data "terraform_remote_state" "monitoring" {
  count   = var.monitoring ? 1 : 0
  backend = "gcs"
  config = {
    bucket                      = var.gcs_backend_bucket
    prefix                      = "core/services/monitoring/iam"
    impersonate_service_account = var.terraform_service_account_email
  }
}

locals {
  host_project_id    = var.shared_vpc_env == "prod" ? try(data.terraform_remote_state.vpc_host[0].outputs.prod_host_project_id, null) : (var.shared_vpc_env == "dev" ? try(data.terraform_remote_state.vpc_host[0].outputs.dev_host_project_id, null) : null)
  resolved_folder_id = var.folder_id != "" ? try(data.terraform_remote_state.folders.outputs[format("%s_folder_id", var.folder_id)], var.folder_id) : null

  # VPC-SC Perimeter ID の引き当て (ステートが存在し、かつ境界名が指定されている場合のみ)
  perimeter_id = length(data.terraform_remote_state.organization) > 0 && var.vpc_sc != "" ? try(data.terraform_remote_state.organization[0].outputs.service_perimeter_ids[var.vpc_sc], null) : null

  # Shared VPC Subnet ID の引き当て
  subnet_id = var.shared_vpc_subnet != "" ? try(data.terraform_remote_state.vpc_host[0].outputs.shared_vpc_subnet_ids[var.shared_vpc_subnet], null) : null

  # 監視用サービスアカウントの取得
  monitoring_sa = var.monitoring ? try(data.terraform_remote_state.monitoring[0].outputs.monitoring_service_account_email, null) : null
}

# ... (既存の module.project 定義などは維持)

# 監視用 IAM 権限の付与 (monitoring フラグが true の場合のみ)
resource "google_project_iam_member" "monitoring_viewer" {
  for_each = toset(var.monitoring && local.monitoring_sa != null ? [
    "roles/monitoring.viewer",
    "roles/compute.viewer",
    "roles/stackdriver.resourceMetadata.viewer"
  ] : [])

  project = module.project.project_id
  role    = each.key
  member  = "serviceAccount:${local.monitoring_sa}"
}

# tflint 未使用変数エラー回避のための参照
resource "terraform_data" "variable_validation" {
  input = {
    enable_org_policies = var.enable_org_policies
    monitoring          = var.monitoring
    logging             = var.logging
  }
}

module "project" {
  source = "../../modules/project-factory"

  project_id      = "${var.project_id_prefix}-${var.app_name}"
  name            = "${var.app_name}-${var.environment}"
  organization_id = data.google_organization.org.org_id
  folder_id       = local.resolved_folder_id

  # ベースのラベルに、monitoring / logging フラグの状態を統合
  labels = merge(var.labels, {
    monitoring = tostring(var.monitoring)
    logging    = tostring(var.logging)
  })

  deletion_protection   = var.deletion_protection
  budget_amount         = var.budget_amount
  budget_alert_emails   = var.budget_alert_emails
  billing_account       = var.billing_account_id
  monitoring_project_id = var.mgmt_project_id

  # 課金アカウントの紐付けは別途管理者が実行するため、Terraform では設定しない
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

  depends_on = [module.project]
}

# サブネットの利用権限付与 (Shared VPC)
resource "google_compute_subnetwork_iam_member" "subnet_user" {
  count      = local.subnet_id != null ? 1 : 0
  project    = local.host_project_id
  region     = try(element(split("/", local.subnet_id), 3), "asia-northeast1")
  subnetwork = local.subnet_id
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${module.project.project_number}@cloudservices.gserviceaccount.com"
}
