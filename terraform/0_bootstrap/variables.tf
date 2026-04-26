variable "project_id" {
  type        = string
  description = "Terraformで操作するGCPプロジェクトのIDです。"
}

variable "gcp_region" {
  type        = string
  default     = "asia-northeast1"
  description = "リソースを作成するデフォルトリージョン。"
}

# --- common.tfvars 用の共通変数 ---
variable "terraform_service_account_email" { type = string }
variable "gcs_backend_bucket" { type = string }
variable "organization_domain" { type = string }
variable "project_id_prefix" { type = string }
variable "core_billing_linked" { type = bool }
variable "enable_vpc_host_projects" { type = bool }
variable "enable_shared_vpc" { type = bool }
variable "enable_vpc_sc" { type = bool }
variable "enable_org_policies" { type = bool }

locals {
  # tflint 対策
  _common_vars = [
    var.terraform_service_account_email,
    var.gcs_backend_bucket,
    var.organization_domain,
    var.project_id_prefix,
    var.core_billing_linked,
    var.enable_vpc_host_projects,
    var.enable_shared_vpc,
    var.enable_vpc_sc,
    var.enable_org_policies
  ]
}

