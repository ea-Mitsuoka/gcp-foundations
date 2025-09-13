# プロジェクトへのIAM権限付与
resource "google_project_iam_member" "project_iam_bindings" {
  for_each = toset(var.roles)

  project = var.project_id
  role    = each.key
  member  = var.member
}
