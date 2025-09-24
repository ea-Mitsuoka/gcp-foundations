output "function_source_bucket_name" {
  description = "The name of the GCS bucket for Cloud Function source code."
  value       = google_storage_bucket.function_source.name
}
