# --------------------------------------------------------------------------------
# Unit tests for project-iam module
# --------------------------------------------------------------------------------

mock_provider "google" {}

variables {
  project_id = "test-proj-12345"
  member     = "user:test@example.com"
  roles      = ["roles/viewer", "roles/editor"]
}

run "grant_project_iam_roles" {
  command = plan

  assert {
    condition     = google_project_iam_member.project_iam_bindings["roles/viewer"].role == "roles/viewer"
    error_message = "Role for viewer does not match expected value"
  }

  assert {
    condition     = google_project_iam_member.project_iam_bindings["roles/viewer"].project == "test-proj-12345"
    error_message = "Project ID for viewer role does not match expected value"
  }

  assert {
    condition     = google_project_iam_member.project_iam_bindings["roles/viewer"].member == "user:test@example.com"
    error_message = "Member for viewer role does not match expected value"
  }

  assert {
    condition     = google_project_iam_member.project_iam_bindings["roles/editor"].role == "roles/editor"
    error_message = "Role for editor does not match expected value"
  }
}

run "empty_roles_list" {
  command = plan

  variables {
    roles = []
  }

  assert {
    condition     = length(google_project_iam_member.project_iam_bindings) == 0
    error_message = "No IAM bindings should be created when roles list is empty"
  }
}
