resource "random_id" "project_suffix" {
  byte_length = 2
}

resource "google_project" "logging_project" {
  project_id = "${var.organization_name}-${var.project_name}-${random_id.project_suffix.hex}"
  name       = "${var.organization_name}-${var.project_name}"
  labels     = var.labels
  org_id     = var.organization_id

  # 課金アカウントの紐付けは別途管理者が実行するため、Terraform では設定しない
  # billing_account = var.billing_account_id
}

# 必要なAPIを有効化
/*
resource "google_project_service" "apis" {
  for_each = var.project_apis

  project                    = google_project.main.project_id
  service                    = each.key
  disable_dependent_services = true
}

  for_each = toset([
    "logging.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com"
  ])
*/
