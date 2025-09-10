# --- このファイルはPythonスクリプトによって自動生成されました ---
data "terraform_remote_state" "project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/projects/logsink"
  }
}

resource "google_bigquery_dataset" "sink_logs" {
  project                    = data.terraform_remote_state.project.outputs.project_id
  dataset_id                 = "sink_logs"
  location                   = var.region
  delete_contents_on_destroy = var.bq_dataset_delete_contents_on_destroy

  labels = {
    purpose = "log-sink-destination"
  }
}

resource "google_storage_bucket" "sink_logs_bucket" {
  project                     = data.terraform_remote_state.project.outputs.project_id
  name                        = "sink-logs-bucket"
  location                    = var.region
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = var.gcs_log_retention_days
    }
  }

  versioning {
    enabled = true
  }
}
