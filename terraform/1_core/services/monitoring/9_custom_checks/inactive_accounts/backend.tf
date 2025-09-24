terraform {
  backend "gcs" {
    prefix = "core/services/monitoring/9_custom_checks/inactive_accounts"
  }
}
