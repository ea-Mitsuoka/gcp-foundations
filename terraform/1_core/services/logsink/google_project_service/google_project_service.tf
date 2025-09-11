# terraform init -backend-config="../../../../common.tfbackend"
# terraform apply -var-file="../../../../common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="../../../../common.tfbackend" -reconfigure

# プロジェクトレベルのサービス有効化
resource "google_project_service" "services" {
  for_each = toset(var.project_apis)

  project = data.terraform_remote_state.project.outputs.project_id
  service = each.value

  disable_on_destroy = false
}
