variable "project_id" {
  type        = string
  description = "The project ID where the log metric will be created."
}
variable "metric_name" {
  type = string
}
variable "metric_filter" {
  type = string
}
