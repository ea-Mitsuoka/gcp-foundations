organization_name = "myorg"

project_apis = [
  # "compute.googleapis.com", # 課金アカウントリンクが必須なためコメントアウト
  "storage.googleapis.com",
  "iam.googleapis.com",
]

labels = {
  env        = "dev"
  app        = "myapp"
  managed-by = "terraform"
}