# export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
# terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
# terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure


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
    var.enable_org_policies,
    var.enable_simplified_admin_groups,
    var.enable_tags,
    var.allow_resource_destruction,
    var.billing_account_id
  ]
}
