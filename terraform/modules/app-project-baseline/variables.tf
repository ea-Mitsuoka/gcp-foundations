variable "organization_domain" {
  type        = string
  description = "The organization domain name."
}

variable "gcs_backend_bucket" {
  type        = string
  description = "The GCS bucket name for Terraform state."
}

variable "project_id_prefix" {
  type        = string
  description = "The prefix for project IDs."
}

variable "app_name" {
  type        = string
  description = "The name of the application."
}

variable "environment" {
  type        = string
  description = "The environment name (prod, stag, dev)."
}

variable "folder_id" {
  type        = string
  default     = ""
  description = "The folder ID to place the project in."
}

variable "vpc_sc" {
  type        = string
  default     = ""
  description = "The name of the VPC-SC perimeter."
}

variable "shared_vpc_subnet" {
  type        = string
  default     = ""
  description = "The name of the shared VPC subnet."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "The labels to apply to the project."
}

variable "terraform_service_account_email" {
  type        = string
  description = "The email of the Terraform service account."
}

variable "shared_vpc_env" {
  type        = string
  default     = "none"
  description = "The shared VPC environment (prod, dev, none)."
}

variable "enable_shared_vpc" {
  type        = bool
  default     = false
  description = "Global switch to enable Shared VPC."
}

variable "enable_vpc_sc" {
  type        = bool
  default     = false
  description = "Global switch to enable VPC Service Controls."
}

variable "enable_org_policies" {
  type        = bool
  default     = false
  description = "Global switch to enable Organization Policies."
}

variable "enable_tags" {
  type        = bool
  default     = false
  description = "Global switch to enable Organization Tags."
}

variable "org_tags" {
  type        = list(string)
  default     = []
  description = "The list of organization tags (key/value format)."
}

variable "central_monitoring" {
  type        = bool
  default     = true
  description = "Whether to enable central monitoring."
}

variable "central_logging" {
  type        = bool
  default     = true
  description = "Whether to enable central logging."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether to enable deletion protection."
}

variable "budget_amount" {
  type        = number
  default     = 0
  description = "The budget amount for the project."
}

variable "budget_alert_emails" {
  type        = list(string)
  default     = []
  description = "The list of emails to receive budget alerts."
}

variable "billing_account_id" {
  type        = string
  default     = null
  description = "The billing account ID."
}

variable "mgmt_project_id" {
  type        = string
  default     = null
  description = "The management project ID."
}
