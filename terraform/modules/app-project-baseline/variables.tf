variable "organization_domain" {
  type = string
}

variable "gcs_backend_bucket" {
  type = string
}

variable "project_id_prefix" {
  type = string
}

variable "app_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "folder_id" {
  type    = string
  default = ""
}

variable "vpc_sc" {
  type    = string
  default = ""
}

variable "shared_vpc_subnet" {
  type    = string
  default = ""
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "terraform_service_account_email" {
  type = string
}

variable "shared_vpc_env" {
  type    = string
  default = "none"
}

variable "enable_shared_vpc" {
  type    = bool
  default = false
}

variable "enable_vpc_sc" {
  type    = bool
  default = false
}

variable "enable_org_policies" {
  type    = bool
  default = false
}

variable "enable_tags" {
  type    = bool
  default = false
}

variable "org_tags" {
  type    = list(string)
  default = []
}

variable "central_monitoring" {
  type    = bool
  default = true
}

variable "central_logging" {
  type    = bool
  default = true
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "budget_amount" {
  type    = number
  default = 0
}

variable "budget_alert_emails" {
  type    = list(string)
  default = []
}

variable "billing_account_id" {
  type    = string
  default = null
}

variable "mgmt_project_id" {
  type    = string
  default = null
}
