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

# --------------------------------------------------------------------------------
# 管理基盤フォルダの作成
# 管理系プロジェクト（logsink, monitoring, tfstate）と
# ネットワーク基盤プロジェクト（vpc-host）を整理するための専用フォルダ。
# 後続レイヤーは data.terraform_remote_state.bootstrap でこのIDを参照する。
# --------------------------------------------------------------------------------

resource "google_folder" "admin" {
  display_name = "admin"
  parent       = "organizations/${data.google_organization.org.org_id}"
}

resource "google_folder" "network" {
  display_name = "network"
  parent       = "organizations/${data.google_organization.org.org_id}"
}
