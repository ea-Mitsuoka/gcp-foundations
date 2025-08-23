module "string_utils" {
  source            = "git::https://gitea.mtskykhd.tokyo/admin/terraform-modules.git//string_utils?ref=ae06918fb2"
  organization_name = var.organization_name
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
  project_id      = "${module.string_utils.sanitized_org_name}-${module.string_utils.sanitized_env}-${module.string_utils.sanitized_app}-${random_id.project_suffix.hex}"
  name            = "${var.labels.app}-${var.labels.env}"
  billing_account = var.billing_account_id
  labels          = var.labels

  org_id    = local.folder_id == null ? var.organization_id : null
  folder_id = local.folder_id # folder_id が null なら無視され、組織直下に作成される
}

resource "google_project_service" "apis" {
  for_each = var.project_apis

  project                    = google_project.main.project_id
  service                    = each.key
  disable_dependent_services = true
}
