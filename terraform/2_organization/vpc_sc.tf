# VPC Service Controls の Access Policy (アクセスレベルや境界の親となるリソース)
resource "google_access_context_manager_access_policy" "access_policy" {
  count  = var.enable_vpc_sc ? 1 : 0
  parent = "organizations/${data.google_organization.org.org_id}"
  title  = "${replace(var.organization_domain, ".", "-")}-default-policy"
}
