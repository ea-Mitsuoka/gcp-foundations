locals {
  # tflint 未使用変数エラー回避のための参照
  _org_policies_enabled = var.enable_org_policies
}

data "google_organization" "org" {
  domain = var.organization_domain
}
