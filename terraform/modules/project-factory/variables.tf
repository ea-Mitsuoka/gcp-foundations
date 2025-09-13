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

variable "billing_account" {
  type        = string
  description = "The ID of the billing account to associate with the project."
  default     = null
}

variable "labels" {
  type        = map(string)
  description = "A map of labels to assign to the project."
  default     = {}
}

variable "auto_create_network" {
  type        = bool
  description = "If true, the default network will be created. Defaults to false."
  default     = false
}