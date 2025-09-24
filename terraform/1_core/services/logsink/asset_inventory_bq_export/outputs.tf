# asset_inventory データセットに関する情報を出力
output "asset_inventory_dataset_info" {
  description = "Information about the BigQuery dataset for Cloud Asset Inventory."
  value = {
    project_id = google_bigquery_dataset.asset_inventory_dataset.project
    dataset_id = google_bigquery_dataset.asset_inventory_dataset.dataset_id
  }
}

# iam_policy テーブルに関する情報を出力
output "iam_policy_table_info" {
  description = "Information about the BigQuery table for IAM policies."
  value = {
    project_id = google_bigquery_table.asset_inventory_iam_policy_table.project
    dataset_id = google_bigquery_table.asset_inventory_iam_policy_table.dataset_id
    table_id   = google_bigquery_table.asset_inventory_iam_policy_table.table_id
  }
}
