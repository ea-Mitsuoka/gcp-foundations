# 自動生成されたファイルです。手動で編集しないでください。

resource "google_access_context_manager_access_level" "office_ip_only" {
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
    "default_perimeter" = google_access_context_manager_service_perimeter.default_perimeter.name
  }
}

output "access_level_ids" {
  value = {
    "office_ip_only" = google_access_context_manager_access_level.office_ip_only.name
  }
}

