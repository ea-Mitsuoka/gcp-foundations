# Cloud Functionが使用する専用のサービスアカウントを作成
resource "google_service_account" "inactive_check_sa" {
  project      = data.terraform_remote_state.monitoring_project.outputs.project_id
  account_id   = "inactive-account-checker"
  display_name = "Service Account for Inactive Account Check"
}

# --- サービスアカウントに必要な権限を付与 ---

# 1. logsinkプロジェクトのBigQueryジョブ実行権限
resource "google_project_iam_member" "sa_bigquery_jobuser_on_logsink" {
  project = data.terraform_remote_state.logsink_project.outputs.project_id
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.inactive_check_sa.member
}

# 2. logsinkプロジェクトのBigQueryデータ閲覧権限
# 注意：より厳密には特定のデータセットに限定すべきですが、ここではプロジェクトレベルで付与します
resource "google_project_iam_member" "sa_bigquery_dataviewer_on_logsink" {
  project = data.terraform_remote_state.logsink_project.outputs.project_id
  role    = "roles/bigquery.dataViewer"
  member  = google_service_account.inactive_check_sa.member
}

# 3. 組織のCloud Asset Inventory閲覧権限
resource "google_organization_iam_member" "sa_asset_viewer_on_org" {
  org_id = data.google_organization.org.org_id
  role   = "roles/cloudasset.viewer"
  member = google_service_account.inactive_check_sa.member
}

# 4. monitoringプロジェクトへのカスタム指標書き込み権限
resource "google_project_iam_member" "sa_monitoring_metricwriter_on_monitoring" {
  project = data.terraform_remote_state.monitoring_project.outputs.project_id
  role    = "roles/monitoring.metricWriter"
  member  = google_service_account.inactive_check_sa.member
}
