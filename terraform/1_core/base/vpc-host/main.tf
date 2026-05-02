# --------------------------------------------------------------------------------
# Shared VPC ホストプロジェクトの作成 (Production & Development)
# enable_vpc_host_projects が true の場合のみ作成されます
# --------------------------------------------------------------------------------

module "vpc_host_prod" {
  source = "../../../modules/project-factory"
  count  = var.enable_vpc_host_projects ? 1 : 0

  project_id          = "${var.project_id_prefix}-vpc-prod"
  name                = "${var.project_id_prefix}-vpc-prod"
  organization_id     = data.google_organization.org.org_id
  folder_id           = try(data.terraform_remote_state.folders.outputs.production_folder_id, null)
  deletion_protection = var.allow_resource_destruction != true
}

module "vpc_host_dev" {
  source = "../../../modules/project-factory"
  count  = var.enable_vpc_host_projects ? 1 : 0

  project_id          = "${var.project_id_prefix}-vpc-dev"
  name                = "${var.project_id_prefix}-vpc-dev"
  organization_id     = data.google_organization.org.org_id
  folder_id           = try(data.terraform_remote_state.folders.outputs.development_folder_id, null)
  deletion_protection = var.allow_resource_destruction != true
}


# --- Compute API Enablement ---
resource "google_project_service" "compute_prod" {
  count              = var.enable_vpc_host_projects ? 1 : 0
  project            = module.vpc_host_prod[0].project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute_dev" {
  count              = var.enable_vpc_host_projects ? 1 : 0
  project            = module.vpc_host_dev[0].project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# --- VPC Networks ---

resource "google_compute_network" "vpc_prod" {
  count                   = var.enable_vpc_host_projects ? 1 : 0
  name                    = "vpc-prod"
  project                 = module.vpc_host_prod[0].project_id
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute_prod]
}

resource "google_compute_network" "vpc_dev" {
  count                   = var.enable_vpc_host_projects ? 1 : 0
  name                    = "vpc-dev"
  project                 = module.vpc_host_dev[0].project_id
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute_dev]
}

# --- Shared VPC Host Enablement ---

resource "google_compute_shared_vpc_host_project" "prod" {
  count      = var.enable_shared_vpc && var.enable_vpc_host_projects ? 1 : 0
  project    = module.vpc_host_prod[0].project_id
  depends_on = [google_compute_network.vpc_prod]
}

resource "google_compute_shared_vpc_host_project" "dev" {
  count      = var.enable_shared_vpc && var.enable_vpc_host_projects ? 1 : 0
  project    = module.vpc_host_dev[0].project_id
  depends_on = [google_compute_network.vpc_dev]
}
