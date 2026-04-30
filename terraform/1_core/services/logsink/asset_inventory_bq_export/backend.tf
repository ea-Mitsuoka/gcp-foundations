terraform {
  backend "gcs" {
    bucket = ""
    prefix = "core/services/logsink/asset_inventory_bq_export"
  }
}
