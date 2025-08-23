organization_name = "myorg"
app               = "myapp"

project_apis = [
  "compute.googleapis.com",
  "storage.googleapis.com",
  "iam.googleapis.com",
]

labels = {
  env        = "dev"
  managed-by = "terraform"
}