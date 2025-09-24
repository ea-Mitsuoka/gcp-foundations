# terraform init
# terraform plan -var-file=terraform.tfvars
# terraform apply -var-file=terraform.tfvars
# terraform init -reconfigure

module "project_services" {
  source = "../../modules/project-services"

  project_id   = var.project_id
  project_apis = var.project_apis
}
