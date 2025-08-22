# "Production"フォルダ
resource "google_folder" "production" {
  display_name        = "Production"
  parent              = "organizations/${var.organization_id}"
  deletion_protection = false
}

# "Development"フォルダ
resource "google_folder" "development" {
  display_name        = "Development"
  parent              = "organizations/${var.organization_id}"
  deletion_protection = false
}
