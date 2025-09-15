# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure
locals {
  # プロジェクトIDで安全に使えるように、ドメイン名のドットをハイフンに置換する
  sanitized_domain = replace(var.organization_domain, ".", "-")
}

# 外部モジュール（string_utils）の呼び出し
module "string_utils" {
  source = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=610dae0"
  # 修正点: データソースからではなく、変数を直接使用
  organization_name = local.sanitized_domain
  env               = var.labels.env
  app               = var.labels.app
}

# プロジェクトID用のランダムな接尾辞
resource "random_id" "project_suffix" {
  byte_length = 2
}

# 新しいproject-factoryモジュールを呼び出す
module "logsink_project" {
  # 1. 新しいモジュールのパスを指定
  source = "../../../modules/project-factory"

  # 2. モジュールに必要な変数を渡す（ここで命名規則を定義）
  # 修正点: データソースからではなく、変数を直接使用
  project_id      = "${local.sanitized_domain}-${var.project_name}-${random_id.project_suffix.hex}"
  name            = "${module.string_utils.sanitized_org_name}-${var.project_name}"
  organization_id = data.google_organization.org.org_id
  labels          = var.labels
  # billing_accountやfolder_idなども必要に応じてここで指定
}
