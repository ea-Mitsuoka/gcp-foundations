# --------------------------------------------------------------------------------
# Unit tests for project-services module
# --------------------------------------------------------------------------------

mock_provider "google" {}

variables {
  project_id         = "test-proj-12345"
  project_apis       = ["compute.googleapis.com", "run.googleapis.com"]
  disable_on_destroy = true
}

run "enable_project_services" {
  command = plan

  assert {
    condition     = google_project_service.services["compute.googleapis.com"].service == "compute.googleapis.com"
    error_message = "Compute API service name does not match expected value"
  }

  assert {
    condition     = google_project_service.services["compute.googleapis.com"].project == "test-proj-12345"
    error_message = "Project ID for Compute API does not match expected value"
  }

  assert {
    condition     = google_project_service.services["compute.googleapis.com"].disable_on_destroy == true
    error_message = "disable_on_destroy should be true"
  }

  assert {
    condition     = google_project_service.services["run.googleapis.com"].service == "run.googleapis.com"
    error_message = "Run API service name does not match expected value"
  }
}

run "empty_apis_list" {
  command = plan

  variables {
    project_apis = []
  }

  assert {
    condition     = length(google_project_service.services) == 0
    error_message = "No services should be created when project_apis is empty"
  }
}
