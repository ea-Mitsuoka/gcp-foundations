# terraform init -backend-config="../../common.tfbackend"
# terraform apply -var-file="../../common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="../../common.tfbackend" -reconfigure

module "project_services" {
  source = "../../modules/project-services"

  project_id   = var.project_id
  project_apis = var.project_apis
}
