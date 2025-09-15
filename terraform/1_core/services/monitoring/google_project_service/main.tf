# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

module "monitoring_project_services" {
  source = "../../../../modules/project-services"

  project_id   = data.terraform_remote_state.project.outputs.project_id
  project_apis = var.project_apis
}
