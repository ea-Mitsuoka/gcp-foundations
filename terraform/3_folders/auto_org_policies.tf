# Auto-generated file. Do not edit manually.

resource "google_org_policy_policy" "production_gcp_resourceLocations" {
  count  = var.enable_org_policies ? 1 : 0
  name   = "folders/${google_folder.production.name}/policies/gcp.resourceLocations"
  parent = "folders/${google_folder.production.name}"
  spec {
    rules {
      values {
        allowed_values = ["asia-northeast1"]
      }
    }
  }
}

