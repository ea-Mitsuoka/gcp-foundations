# --------------------------------------------------------------------------------
# Shared VPC ホストプロジェクトの作成 (Production & Development)
# enable_vpc_host_projects が true の場合のみ作成されます
# --------------------------------------------------------------------------------

module "vpc_host_prod" {
  source = "../../../modules/project-factory"
  count  = var.enable_vpc_host_projects ? 1 : 0

  project_id      = "${var.project_id_prefix}-vpc-prod"
  name            = "${var.project_id_prefix}-vpc-prod"
  organization_id = data.google_organization.org.org_id
  folder_id       = try(data.terraform_remote_state.folders.outputs.production_folder_id, null)

}

module "vpc_host_dev" {
  source = "../../../modules/project-factory"
  count  = var.enable_vpc_host_projects ? 1 : 0

  project_id      = "${var.project_id_prefix}-vpc-dev"
  name            = "${var.project_id_prefix}-vpc-dev"
  organization_id = data.google_organization.org.org_id
  folder_id       = try(data.terraform_remote_state.folders.outputs.development_folder_id, null)
}
