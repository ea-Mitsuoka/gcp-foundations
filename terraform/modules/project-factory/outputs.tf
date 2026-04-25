output "project_id" {
  description = "The ID of the created project."
  value       = google_project.this.project_id
}

output "project_name" {
  description = "The display name of the created project."
  value       = google_project.this.name
}

output "project_number" {
  description = "The numeric ID of the created project."
  value       = google_project.this.number
}
