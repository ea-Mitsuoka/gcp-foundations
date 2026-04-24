# --------------------------------------------------------------------------------
# Shared VPC ネットワークの設定
# enable_shared_vpc および enable_vpc_host_projects が true の場合のみ実行されます
# --------------------------------------------------------------------------------

# 1. Compute Engine API の有効化
resource "google_project_service" "compute_prod" {
  provider           = google-beta
  count              = var.enable_shared_vpc && var.enable_vpc_host_projects ? 1 : 0
  project            = data.terraform_remote_state.vpc_host.outputs.prod_host_project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute_dev" {
  provider           = google-beta
  count              = var.enable_shared_vpc && var.enable_vpc_host_projects ? 1 : 0
  project            = data.terraform_remote_state.vpc_host.outputs.dev_host_project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# 2. Shared VPC ホストプロジェクト機能の有効化
resource "google_compute_shared_vpc_host_project" "host_prod" {
  provider   = google-beta
  count      = var.enable_shared_vpc && var.enable_vpc_host_projects ? 1 : 0
  project    = data.terraform_remote_state.vpc_host.outputs.prod_host_project_id
  depends_on = [google_project_service.compute_prod]
}

resource "google_compute_shared_vpc_host_project" "host_dev" {
  provider   = google-beta
  count      = var.enable_shared_vpc && var.enable_vpc_host_projects ? 1 : 0
  project    = data.terraform_remote_state.vpc_host.outputs.dev_host_project_id
  depends_on = [google_project_service.compute_dev]
}


