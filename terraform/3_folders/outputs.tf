output "production_folder_id" {
  description = "The ID of the Production folder."
  value       = google_folder.production.id
}

output "development_folder_id" {
  description = "The ID of the Development folder."
  value       = google_folder.development.id
}
