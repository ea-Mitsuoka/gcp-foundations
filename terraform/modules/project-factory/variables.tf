variable "project_id" {
  type        = string
  description = "The ID of the project."
}

variable "name" {
  type        = string
  description = "The display name of the project."
}

variable "organization_id" {
  type        = string
  description = "The organization ID to create the project in."
}

variable "folder_id" {
  type        = string
  description = "The folder ID to create the project in. If null, project will be created at the organization level."
  default     = null
}

variable "labels" {
  type        = map(string)
  description = "A map of labels to assign to the project."
  default     = {}
}

variable "auto_create_network" {
  type        = bool
  description = "If true, the default network will be created. Defaults to true."
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Whether or not to protect the project from deletion. Internally mapped to google_project's deletion_policy (PREVENT/DELETE). Default is true."
  default     = true
}

variable "budget_amount" {
  type        = number
  description = "The monthly budget amount for the project. If 0, no budget alert is created."
  default     = 0
}

variable "billing_account" {
  type        = string
  description = "The billing account ID to associate the budget with. Required if budget_amount > 0."
  default     = null
}

variable "monitoring_project_id" {
  type        = string
  description = "The ID of the project where notification channels will be created (usually the management or central monitoring project)."
  default     = null
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "List of additional email addresses to receive budget alerts."
  default     = []
}