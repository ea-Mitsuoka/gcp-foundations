variable "project_id" {
  type        = string
  description = "The ID of the project for which to enable APIs."
}

variable "project_apis" {
  type        = set(string)
  description = "A list of APIs to enable for the project."
  default     = []
}

variable "disable_on_destroy" {
  type        = bool
  description = "A flag to control the disable_on_destroy attribute of the google_project_service resource."
  default     = false
}