variable "project_id" {
  type        = string
  description = "The ID of the project in which the resource belongs."
}

variable "display_name" {
  type        = string
  description = "A user-assigned name for this resource."
}

variable "filter" {
  type        = string
  description = "A filter that identifies which log entries to monitor."
}

variable "documentation" {
  type        = string
  description = "Documentation for the alert policy, in Markdown format."
  default     = "No documentation provided."
}

variable "notification_channel_ids" {
  type        = list(string)
  description = "A list of notification channel IDs to which notifications will be sent when the alert is triggered."
  default     = []
}
