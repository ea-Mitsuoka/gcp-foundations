variable "scoping_project_id" {
  type = string
}
variable "monitored_project_id" {
  type = string
}
variable "alert_display_name" {
  type = string
}
variable "alert_documentation" {
  type = string
}
variable "metric_type" {
  type = string
}
variable "notification_channel_ids" {
  type    = list(string)
  default = []
}
