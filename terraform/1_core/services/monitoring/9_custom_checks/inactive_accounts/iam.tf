# Cloud Functionが使用する専用のサービスアカウントを作成
resource "google_service_account" "inactive_check_sa" {
  project      = data.terraform_remote_state.monitoring_project.outputs.project_id
  account_id   = "inactive-account-checker"
  display_name = "Service Account for Inactive Account Check"
}

# --- ▼▼▼ ここからがリファクタリング箇所 ▼▼▼ ---

# logsinkプロジェクトに付与するロールをlocalsで定義
locals {
  logsink_project_roles = toset([
    "roles/bigquery.jobUser",
    "roles/bigquery.dataViewer",
  ])
}

# 【改善後】logsinkプロジェクトへの権限をfor_eachでまとめて付与
resource "google_project_iam_member" "sa_roles_on_logsink" {
  for_each = local.logsink_project_roles

  project = data.terraform_remote_state.logsink_project.outputs.project_id
  role    = each.key
  member  = google_service_account.inactive_check_sa.member
}

# --- ▲▲▲ ここまでがリファクタリング箇所 ▲▲▲ ---


# 組織のCloud Asset Inventory閲覧権限 (対象が組織のため、別リソースとして定義)
resource "google_organization_iam_member" "sa_asset_viewer_on_org" {
  org_id = data.google_organization.org.org_id
  role   = "roles/cloudasset.viewer"
  member = google_service_account.inactive_check_sa.member
}

# monitoringプロジェクトへのカスタム指標書き込み権限 (対象がmonitoringプロジェクトのため、別リソースとして定義)
resource "google_project_iam_member" "sa_monitoring_metricwriter_on_monitoring" {
  project = data.terraform_remote_state.monitoring_project.outputs.project_id
  role    = "roles/monitoring.metricWriter"
  member  = google_service_account.inactive_check_sa.member
}
