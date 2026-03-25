data "external" "org_name" {
  program = ["bash", "../../scripts/get-organization-name.sh"]
}

data "external" "org_id" {
  program = ["bash", "../../scripts/get-organization-id.sh"]
}

module "string_utils" {
  source            = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=535a37e77566e68ab35b1f5266cb1872405f15a2"
  organization_name = data.external.org_name.result.organization_name
  env               = var.labels.env
  app               = var.labels.app
}

resource "random_id" "project_suffix" {
  byte_length = 2
}

locals {
  folder_id = var.folder_path != "" ? var.folder_path : null
}

resource "google_project" "main" {
  project_id = "${data.external.org_name.result.organization_name}-${module.string_utils.sanitized_env}-${module.string_utils.sanitized_app}-${random_id.project_suffix.hex}"
  name       = "${module.string_utils.sanitized_org_name}-${module.string_utils.sanitized_env}-${module.string_utils.sanitized_app}"
  org_id     = local.folder_id == null ? data.external.org_id.result.organization_id : null
  folder_id  = local.folder_id # folder_id が null なら無視され、組織直下に作成される
  labels     = var.labels

  # 課金アカウントの紐付けは別途管理者が実行するため、Terraform では設定しない
  # billing_account = var.billing_account_id
}

resource "google_project_service" "apis" {
  for_each = var.project_apis

  project                    = google_project.main.project_id
  service                    = each.key
  disable_dependent_services = true
}
