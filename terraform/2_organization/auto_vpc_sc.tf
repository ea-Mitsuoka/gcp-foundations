# Auto-generated file. Do not edit manually.

resource "google_access_context_manager_access_level" "office_ip_only" {
  count  = var.enable_vpc_sc ? 1 : 0
  parent = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}/accessLevels/office_ip_only"
  title  = "office_ip_only"
  basic {
    conditions {
      ip_subnetworks = ["1.2.3.4/32"]
      members        = ["user:admin@example.com"]
    }
  }
}

resource "google_access_context_manager_service_perimeter" "default_perimeter" {
  count  = var.enable_vpc_sc ? 1 : 0
  parent = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}/servicePerimeters/default_perimeter"
  title  = "default_perimeter"
  status {
    restricted_services = ["storage.googleapis.com", "bigquery.googleapis.com", "compute.googleapis.com"]
  }
  lifecycle {
    ignore_changes = [status[0].resources]
  }
}

output "service_perimeter_ids" {
  value = {
    "default_perimeter" = var.enable_vpc_sc ? google_access_context_manager_service_perimeter.default_perimeter[0].name : null
  }
}

output "access_level_ids" {
  value = {
    "office_ip_only" = var.enable_vpc_sc ? google_access_context_manager_access_level.office_ip_only[0].name : null
  }
}

