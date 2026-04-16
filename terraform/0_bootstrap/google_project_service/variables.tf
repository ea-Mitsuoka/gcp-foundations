variable "project_id" {
  type        = string
  description = "bootstrap用のGCPプロジェクトID。"
}

variable "project_apis" {
  type        = set(string)
  description = "プロジェクトで有効化するAPIのリスト。"
  default = [
    "cloudresourcemanager.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "iamcredentials.googleapis.com"
  ]
}

# Warning 抑制用
variable "terraform_service_account_email" {
  type    = string
  default = ""
}

variable "gcs_backend_bucket" {
  type    = string
  default = ""
}

variable "organization_domain" {
  type    = string
  default = ""
}

variable "gcp_region" {
  type    = string
  default = ""
}

variable "project_id_prefix" {
  type    = string
  default = ""
}

variable "core_billing_linked" {
  type    = bool
  default = false
}