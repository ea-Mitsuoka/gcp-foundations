# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# set-gcs-bucket-value.sh .
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

module "monitoring_iam" {
  source = "../../../../modules/project-iam"

  project_id = data.terraform_remote_state.project.outputs.project_id
  member     = "serviceAccount:${var.terraform_service_account_email}"
  roles      = var.roles
}
