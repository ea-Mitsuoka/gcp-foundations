# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# set-gcs-bucket-value.sh .
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

# logsinkプロジェクトの情報をリモートステートから取得
data "terraform_remote_state" "logsink_project" {
  backend = "gcs"
  config = {
    bucket = var.gcs_backend_bucket
    prefix = "core/base/logsink"
  }
}

# 共有のセキュリティ分析用データセットを作成
resource "google_bigquery_dataset" "analytics_dataset" {
  project     = data.terraform_remote_state.logsink_project.outputs.project_id
  dataset_id  = "security_analytics"
  location    = var.gcp_region
  description = "Dataset for various security analytics views."
}
