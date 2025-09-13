# terraform init -backend-config="../../../common.tfbackend"
# terraform apply -var-file="../../../common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="../../../common.tfbackend" -reconfigure

# 外部モジュール（string_utils）の呼び出し
module "string_utils" {
  source            = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=610dae09b1"
  organization_name = data.google_organization.org.name
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
  project_id      = "${data.google_organization.org.name}-${var.project_name}-${random_id.project_suffix.hex}"
  name            = "${module.string_utils.sanitized_org_name}-${var.project_name}"
  organization_id = data.google_organization.org.org_id
  labels          = var.labels
}
