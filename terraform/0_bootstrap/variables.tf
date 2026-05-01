variable "project_id" {
  type        = string
  description = "The ID of the seed project for Terraform state."
}

variable "gcp_region" {
  type        = string
  default     = "asia-northeast1"
  description = "The default region for bootstrap resources."
}

variable "terraform_service_account_email" {
  type        = string
  description = "Email of the Terraform management service account."
}

variable "gcs_backend_bucket" {
  type        = string
  description = "Name of the GCS bucket for Terraform state."
}

variable "organization_domain" {
  type        = string
  description = "The GCP organization domain name."
}

variable "project_id_prefix" {
  type        = string
  description = "Prefix used for all generated project IDs."
}

variable "core_billing_linked" {
  type        = bool
  description = "Flag indicating if billing is linked to core projects."
}

variable "enable_vpc_host_projects" {
  type        = bool
  description = "Whether to create Shared VPC host projects."
}

variable "enable_shared_vpc" {
  type        = bool
  description = "Whether to enable Shared VPC across the organization."
}

variable "enable_vpc_sc" {
  type        = bool
  description = "Whether to enable VPC Service Controls."
}

variable "enable_org_policies" {
  type        = bool
  description = "Whether to enable organization policies."
}

variable "enable_simplified_admin_groups" {
  type        = bool
  description = "Whether to use the 2-group simplified admin model."
}
