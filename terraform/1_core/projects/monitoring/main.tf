# terraform init -backend-config="../../../common.tfbackend"
# terraform apply -var-file="../../../common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="../../../common.tfbackend" -reconfigure

module "logsink_project" {
  # 1. 作成したモジュールのパスを指定
  source = "../../../modules/gcp-project"

  # 2. モジュールに必要な変数を渡す
  organization_id   = data.external.org_id.result.organization_id
  organization_name = data.external.org_name.result.organization_name
  project_name      = var.project_name
  labels            = var.labels
}
