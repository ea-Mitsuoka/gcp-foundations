# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

## 新しいproject-factoryモジュールを呼び出す
module "logsink_project" {
  # 1. 新しいモジュールのパスを指定
  source = "../../../modules/project-factory"

  # 2. モジュールに必要な変数を渡す（ここで命名規則を定義）
  # 修正点: データソースからではなく、変数を直接使用
  project_id          = "${var.project_id_prefix}-${var.project_name}"
  name                = "${var.project_id_prefix}-${var.project_name}"
  organization_id     = data.google_organization.org.org_id
  billing_account     = var.billing_account_id
  labels              = var.labels
  deletion_protection = var.allow_resource_destruction != true
  # billing_accountやfolder_idなども必要に応じてここで指定
}
