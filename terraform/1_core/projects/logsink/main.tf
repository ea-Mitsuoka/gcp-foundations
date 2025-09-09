data "external" "org_name" {
  program = ["bash", "../../scripts/get-organization-name.sh"]
}

data "external" "org_id" {
  program = ["bash", "../../scripts/get-organization-id.sh"]
}

module "string_utils" {
  source            = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=610dae09b1"
  organization_name = data.external.org_name.result.organization_name
  env               = var.labels.env
  app               = var.labels.app
}

resource "random_id" "project_suffix" {
  byte_length = 2
}

resource "google_project" "logsink_project" {
  project_id = "${data.external.org_name.result.organization_name}-${var.project_name}-${random_id.project_suffix.hex}"
  name       = "${module.string_utils.sanitized_org_name}-${var.project_name}"
  org_id     = data.external.org_id.result.organization_id
  labels     = var.labels

  # 課金アカウントの紐付けは別途管理者が実行するため、Terraform では設定しない
  # billing_account = var.billing_account_id
}
