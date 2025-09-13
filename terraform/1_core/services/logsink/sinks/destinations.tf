# BigQueryデータセットを動的に作成
resource "google_bigquery_dataset" "dynamic_datasets" {
  for_each = local.unique_bigquery_datasets

  project                     = data.terraform_remote_state.project.outputs.project_id
  dataset_id                  = each.key
  location                    = var.region
  delete_contents_on_destroy  = var.bq_dataset_delete_contents_on_destroy
  default_table_expiration_ms = each.value.retention_days * 24 * 60 * 60 * 1000

  labels = {
    purpose = "log-sink-destination"
  }
}

# Cloud Storageバケットを動的に作成
resource "google_storage_bucket" "dynamic_buckets" {
  for_each = local.unique_gcs_buckets

  project                     = data.terraform_remote_state.project.outputs.project_id
  name                        = each.key
  location                    = var.region
  uniform_bucket_level_access = true

  # 静的なライフサイクルルール
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition { age = 30 }
  }
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition { age = 90 }
  }
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
    condition { age = 365 }
  }

  # Pythonの仕様通り、CSVから取得した日数で削除ルールを動的に設定
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = each.value.retention_days
    }
  }

  versioning {
    enabled = true
  }
}
