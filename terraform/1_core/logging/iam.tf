# --- このファイルはPythonスクリプトによって自動生成されました ---
resource "google_project_iam_member" "admin_activity_audit_logs_sink_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_organization_log_sink.admin_activity_audit_logs_sink.writer_identity
}

resource "google_project_iam_member" "data_access_audit_logs_sink_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_organization_log_sink.data_access_audit_logs_sink.writer_identity
}

resource "google_project_iam_member" "vpc_flow_logs_sink_writer" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = google_organization_log_sink.vpc_flow_logs_sink.writer_identity
}

resource "google_project_iam_member" "billing_logs_sink_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_organization_log_sink.billing_logs_sink.writer_identity
}
