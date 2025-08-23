organization_name = "myorg"

project_apis = [
  "compute.googleapis.com",
  "storage.googleapis.com",
  "iam.googleapis.com",
]

labels = {
  env        = "dev"
  app        = "myapp"
  managed-by = "terraform"
}