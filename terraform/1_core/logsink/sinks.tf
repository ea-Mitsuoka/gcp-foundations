# --- このファイルはPythonスクリプトによって自動生成されました ---
data "terraform_remote_state" "project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/projects/logsink"
  }
}

data "external" "org_id" {
  program = ["bash", "../../scripts/get-organization-id.sh"]
}

resource "google_organization_log_sink" "admin_activity_audit_logs_sink" {
  name                   = "org-admin_activity_audit_logs-sink"
  org_id                 = data.external.org_id.result.organization_id
  filter                 = "logName:\"logs/cloudaudit.googleapis.com%2Factivity\" OR logName:\"logs/cloudaudit.googleapis.com%2Fsystem_event\""
  destination            = "bigquery.googleapis.com/projects/${data.terraform_remote_state.project.outputs.project_id}/datasets/sink_logs"
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_organization_log_sink" "data_access_audit_logs_sink" {
  name                   = "org-data_access_audit_logs-sink"
  org_id                 = data.external.org_id.result.organization_id
  filter                 = "logName:\"logs/cloudaudit.googleapis.com%2Fdata_access\""
  destination            = "bigquery.googleapis.com/projects/${data.terraform_remote_state.project.outputs.project_id}/datasets/sink_logs"
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_organization_log_sink" "vpc_flow_logs_sink" {
  name                   = "org-vpc_flow_logs-sink"
  org_id                 = data.external.org_id.result.organization_id
  filter                 = "resource.type=\"gce_subnetwork\" AND logName:\"logs/compute.googleapis.com%2Fvpc_flows\""
  destination            = "storage.googleapis.com/sink-logs-bucket"
  unique_writer_identity = true
}

resource "google_organization_log_sink" "billing_logs_sink" {
  name                   = "org-billing_logs-sink"
  org_id                 = data.external.org_id.result.organization_id
  filter                 = "logName:\"logs/billing.googleapis.com%2Fbilling_account\""
  destination            = "bigquery.googleapis.com/projects/${data.terraform_remote_state.project.outputs.project_id}/datasets/sink_logs"
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }
}
