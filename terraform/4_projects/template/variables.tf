variable "organization_domain" {
  description = "The organization domain name."
  type        = string
}

variable "mgmt_project_id" {
  description = "The project ID of the management/monitoring project."
  type        = string
}

variable "app_name" {
  description = "The name of the application."
  type        = string
}

variable "environment" {
  description = "The environment name (prod, stag, dev)."
  type        = string
}

variable "folder_id" {
  description = "The folder ID to place the project in."
  type        = string
  default     = ""
}

variable "shared_vpc_env" {
  description = "The shared VPC environment (prod, dev, none)."
  type        = string
  default     = "none"
}

variable "shared_vpc_subnet" {
  description = "The name of the shared VPC subnet."
  type        = string
  default     = ""
}

variable "vpc_sc" {
  description = "The name of the VPC-SC perimeter."
  type        = string
  default     = ""
}

variable "central_monitoring" {
  description = "Whether to enable central monitoring."
  type        = bool
  default     = true
}

variable "central_logging" {
  description = "Whether to enable central logging."
  type        = bool
  default     = true
}

variable "budget_amount" {
  description = "The budget amount for the project."
  type        = number
  default     = 0
}

variable "budget_alert_emails" {
  description = "The list of emails to receive budget alerts."
  type        = list(string)
  default     = []
}

variable "org_tags" {
  description = "The list of organization tags (key/value format)."
  type        = list(string)
  default     = []
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection for the project."
  type        = bool
  default     = true
}

variable "labels" {
  description = "The labels to apply to the project."
  type        = map(string)
  default     = {}
}

# --- Infrastructure Global Variables (Passed via -var-file) ---

variable "gcs_backend_bucket" {
  description = "The GCS bucket for Terraform state."
  type        = string
}

variable "terraform_service_account_email" {
  description = "The email of the Terraform service account."
  type        = string
}

variable "project_id_prefix" {
  description = "The prefix for project IDs."
  type        = string
}

variable "billing_account_id" {
  description = "The billing account ID."
  type        = string
}

variable "enable_shared_vpc" {
  description = "Global switch to enable Shared VPC."
  type        = bool
  default     = false
}

variable "enable_vpc_sc" {
  description = "Global switch to enable VPC Service Controls."
  type        = bool
  default     = false
}

variable "enable_org_policies" {
  description = "Global switch to enable Organization Policies."
  type        = bool
  default     = false
}

variable "enable_tags" {
  description = "Global switch to enable Organization Tags."
  type        = bool
  default     = false
}
