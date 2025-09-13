data "google_organization" "org" {
  # 注入された変数を参照
  domain = var.organization_domain
}
