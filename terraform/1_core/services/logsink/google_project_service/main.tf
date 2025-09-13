# terraform init -backend-config="../../../../common.tfbackend"
# terraform apply -var-file="../../../../common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="../../../../common.tfbackend" -reconfigure

module "logsink_project_services" {
  source = "../../../../modules/project-services"

  project_id   = data.terraform_remote_state.project.outputs.project_id
  project_apis = var.project_apis
}
