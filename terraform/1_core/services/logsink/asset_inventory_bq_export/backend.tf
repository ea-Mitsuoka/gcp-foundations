terraform {
  backend "gcs" {
    prefix = "core/services/logsink/asset_inventory_bq_export"
  }
}
