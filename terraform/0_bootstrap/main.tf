# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

# Cloud Functionのソースコード(ZIP)を保管するためのGCSバケット
resource "google_storage_bucket" "function_source" {
  # var.project_id は 0_bootstrap で作成する管理用プロジェクトIDを指します
  project = var.project_id

  # バケット名はグローバルで一意にする必要があるため、プロジェクトIDを含めることを推奨します
  name = "${var.project_id}-function-source"

  # リージョンは他のリソースと合わせます
  location = var.gcp_region

  # 推奨：均一なバケットレベルのアクセス制御を有効化
  uniform_bucket_level_access = true

  # 推奨：ソースコードのバージョン管理のため、バージョニングを有効化
  versioning {
    enabled = true
  }

  # パブリックアクセスを禁止
  public_access_prevention = "enforced"
}

# tflint 未使用変数エラー回避のための参照
resource "terraform_data" "variable_validation" {
  input = [
    var.terraform_service_account_email,
    var.gcs_backend_bucket,
    var.organization_domain,
    var.project_id_prefix,
    var.core_billing_linked,
    var.enable_vpc_host_projects,
    var.enable_shared_vpc,
    var.enable_vpc_sc,
    var.enable_org_policies
  ]
}
