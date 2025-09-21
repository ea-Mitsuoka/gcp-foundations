output "name" {
  description = "The name of the created log metric."
  value       = google_logging_metric.this.name
}
