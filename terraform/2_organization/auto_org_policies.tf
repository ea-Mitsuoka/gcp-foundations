# Auto-generated file. Do not edit manually.

resource "google_org_policy_policy" "compute_disableExternalIPProxy" {
  count  = var.enable_org_policies ? 1 : 0
  name   = "organizations/${data.google_organization.org.org_id}/policies/compute.disableExternalIPProxy"
  parent = "organizations/${data.google_organization.org.org_id}"
  spec {
    rules {
      deny_all = "true"
    }
  }
}

