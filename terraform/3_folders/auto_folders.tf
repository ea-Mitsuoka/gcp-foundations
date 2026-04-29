# Auto-generated file. Do not edit manually.

resource "google_folder" "shared" {
  display_name        = "shared"
  parent              = data.google_organization.org.name
  deletion_protection = false
}

output "shared_folder_id" {
  value = google_folder.shared.id
}

resource "google_folder" "production" {
  display_name        = "production"
  parent              = google_folder.shared.name
  deletion_protection = false
}

output "production_folder_id" {
  value = google_folder.production.id
}

