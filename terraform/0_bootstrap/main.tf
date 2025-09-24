# terraform init
# terraform plan -var-file=terraform.tfvars
# terraform apply -var-file=terraform.tfvars
# terraform init -reconfigure

# Cloud Functionのソースコード(ZIP)を保管するためのGCSバケット
resource "google_storage_bucket" "function_source" {
  # var.project_id は 0_bootstrap で作成する管理用プロジェクトIDを指します
  project = var.project_id

  # バケット名はグローバルで一意にする必要があるため、プロジェクトIDを含めることを推奨します
  name = "${var.project_id}-function-source"

  # リージョンは他のリソースと合わせます
  location = var.region

  # 推奨：均一なバケットレベルのアクセス制御を有効化
  uniform_bucket_level_access = true

  # 推奨：ソースコードのバージョン管理のため、バージョニングを有効化
  versioning {
    enabled = true
  }

  # パブリックアクセスを禁止
  public_access_prevention = "enforced"
}
