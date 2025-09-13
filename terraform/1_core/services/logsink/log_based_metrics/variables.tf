variable "gcs_backend_bucket" {
  description = "The name of the GCS bucket used for Terraform state."
  type        = string
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "labels" {
  type        = map(string)
  description = "プロジェクトに付与するラベル。"
  default     = {}
}
