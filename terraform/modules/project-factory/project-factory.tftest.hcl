# --------------------------------------------------------------------------------
# Unit tests for project-factory module
# --------------------------------------------------------------------------------

mock_provider "google" {}

variables {
  project_id      = "test-proj-12345"
  name            = "Test Project"
  organization_id = "123456789012"
  folder_id       = null
  labels = {
    env = "dev"
    app = "test"
  }
  auto_create_network = false
}

run "create_project_org_level" {
  command = plan

  assert {
    condition     = google_project.this.project_id == "test-proj-12345"
    error_message = "Project ID does not match expected value"
  }

  assert {
    condition     = google_project.this.name == "Test Project"
    error_message = "Project Name does not match expected value"
  }

  assert {
    condition     = google_project.this.org_id == "123456789012"
    error_message = "Organization ID does not match expected value"
  }

  assert {
    condition     = google_project.this.folder_id == null
    error_message = "Folder ID should be null"
  }

  assert {
    condition     = google_project.this.auto_create_network == false
    error_message = "Auto create network should be false"
  }
}

run "create_project_folder_level" {
  command = plan

  variables {
    folder_id = "folders/987654321"
  }

  assert {
    condition     = google_project.this.folder_id == "folders/987654321"
    error_message = "Folder ID does not match expected value"
  }

  assert {
    condition     = google_project.this.org_id == null
    error_message = "Organization ID should be null when folder_id is provided"
  }
}
