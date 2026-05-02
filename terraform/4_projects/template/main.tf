# --------------------------------------------------------------------------------
# 基盤提供のベースライン設定 (変更不要)
# プロジェクト作成、VPC/VPC-SCの紐付け、中央監視連携などを隠蔽して実行します。
# --------------------------------------------------------------------------------
module "baseline" {
  source = "../../modules/app-project-baseline"

  organization_domain             = var.organization_domain
  gcs_backend_bucket              = var.gcs_backend_bucket
  terraform_service_account_email = var.terraform_service_account_email
  project_id_prefix               = var.project_id_prefix
  app_name                        = var.app_name
  environment                     = var.environment
  folder_id                       = var.folder_id
  vpc_sc                          = var.vpc_sc
  shared_vpc_subnet               = var.shared_vpc_subnet
  labels                          = var.labels
  shared_vpc_env                  = var.shared_vpc_env
  enable_shared_vpc               = var.enable_shared_vpc
  enable_vpc_sc                   = var.enable_vpc_sc
  enable_org_policies             = var.enable_org_policies
  enable_tags                     = var.enable_tags
  org_tags                        = var.org_tags
  central_monitoring              = var.central_monitoring
  central_logging                 = var.central_logging
  deletion_protection             = var.deletion_protection && var.allow_resource_destruction != true
  budget_amount                   = var.budget_amount
  budget_alert_emails             = var.budget_alert_emails
  billing_account_id              = var.billing_account_id
  mgmt_project_id                 = var.mgmt_project_id
}

# --------------------------------------------------------------------------------
# 現場領域 (Application Infrastructure)
# 以下に、このアプリケーションで必要なAPI有効化やリソースを自由に定義してください。
# --------------------------------------------------------------------------------

# 例: アプリケーションに必要なAPIの有効化
# module "project_services" {
#   source = "../../modules/project-services"
#   project_id   = module.baseline.project_id
#   project_apis = ["run.googleapis.com", "sqladmin.googleapis.com"]
# }

# 例: サービスアカウントの作成
# resource "google_service_account" "app_sa" {
#   project      = module.baseline.project_id
#   account_id   = "app-service-account"
#   display_name = "Application Service Account"
# }
