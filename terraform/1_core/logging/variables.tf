variable "org_id" {
  type        = string
  description = "Google Cloud Organization ID."
}

variable "billing_account" {
  type        = string
  description = "Billing account ID to associate with the project."
}

variable "folder_id" {
  type        = string
  description = "Folder ID where the logging project will be created."
  default     = null # 組織直下に作成する場合はnull
}

variable "project_id" {
  type        = string
  description = "The ID of the logging project."
  default     = "gcp-log-aggregation"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

# BigQuery
variable "bq_dataset_name" {
  type    = string
  default = "audit_logs"
}

variable "bq_dataset_delete_contents_on_destroy" {
  type        = bool
  description = "If set to true, deletes all tables in the dataset when the dataset is destroyed."
  default     = false
}

# Cloud Storage
variable "gcs_bucket_name_for_flow_logs" {
  type        = string
  description = "The name of GCS bucket for flow logs."
  default     = "gcp-flow-logs-bucket" # Note: Bucket names must be globally unique
}

variable "gcs_log_retention_days" {
  type        = number
  description = "The number of days to retain logs in the GCS bucket."
  default     = 365
}