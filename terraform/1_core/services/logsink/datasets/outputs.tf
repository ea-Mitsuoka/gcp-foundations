output "analytics_dataset_id" {
  description = "The ID of the security_analytics dataset."
  value       = google_bigquery_dataset.analytics_dataset.dataset_id
}

output "analytics_dataset_project" {
  description = "The Project ID where the security_analytics dataset resides."
  value       = google_bigquery_dataset.analytics_dataset.project
}
