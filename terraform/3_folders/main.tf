data "google_organization" "org" {
  domain = var.organization_domain
}

# "Production"フォルダ
resource "google_folder" "production" {
  display_name = "Production"
  parent       = data.google_organization.org.name

  # destroy（削除）を許可するフラグ
  deletion_protection = false
}

# "Development"フォルダ
resource "google_folder" "development" {
  display_name = "Development"
  parent       = data.google_organization.org.name

  # destroy（削除）を許可するフラグ
  deletion_protection = false
}
