# Auto-generated file. Do not edit manually.

resource "google_folder" "production" {
  display_name        = "production"
  parent              = data.google_organization.org.name
  deletion_protection = false
}

output "production_folder_id" {
  description = "The resource ID of the production folder."
  value       = google_folder.production.id
}

resource "google_folder" "development" {
  display_name        = "development"
  parent              = data.google_organization.org.name
  deletion_protection = false
}

output "development_folder_id" {
  description = "The resource ID of the development folder."
  value       = google_folder.development.id
}

