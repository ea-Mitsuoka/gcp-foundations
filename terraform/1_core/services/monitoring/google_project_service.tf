# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# set-gcs-bucket-value.sh .
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

# プロジェクトレベルのサービス有効化
resource "google_project_service" "services" {
  for_each = toset(var.project_apis)

  project = data.terraform_remote_state.project.outputs.project_id
  service = each.value

  disable_on_destroy = false
}
