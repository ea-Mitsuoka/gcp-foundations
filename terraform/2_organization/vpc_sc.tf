# VPC Service Controls の Access Policy (アクセスレベルや境界の親となるリソース)
resource "google_access_context_manager_access_policy" "access_policy" {
  count  = var.enable_vpc_sc ? 1 : 0
  parent = "organizations/${data.google_organization.org.org_id}"
  title  = "${replace(var.organization_domain, ".", "-")}-default-policy"
}

# デフォルトのサービス境界 (最初は空。プロジェクト側で後から自身を追加する)
resource "google_access_context_manager_service_perimeter" "default_perimeter" {
  count  = var.enable_vpc_sc ? 1 : 0
  parent = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}/servicePerimeters/default_perimeter"
  title  = "default_perimeter"

  status {
    restricted_services = [
      "storage.googleapis.com",
      "bigquery.googleapis.com",
      "compute.googleapis.com"
    ]
    # resources はここでは空にし、4_projects 側で google_access_context_manager_service_perimeter_resource を使って自身を追加する
  }
}
