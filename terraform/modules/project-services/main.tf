# プロジェクトレベルのサービス有効化
resource "google_project_service" "services" {
  for_each = toset(var.project_apis)

  project = var.project_id
  service = each.value

  disable_on_destroy = var.disable_on_destroy
}
