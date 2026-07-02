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
    condition     = google_project.this.folder_id == "987654321"
    error_message = "Folder ID does not match expected value"
  }

  assert {
    condition     = google_project.this.org_id == null
    error_message = "Organization ID should be null when folder_id is provided"
  }
}

# billing_account = null（manual/手動運用）: Terraform は課金リンクを設定せず、
# 予算(google_billing_budget)も作らない。
run "manual_billing_unmanaged_and_no_budget" {
  command = plan

  variables {
    billing_account = null
    budget_amount   = 50000
  }

  assert {
    condition     = google_project.this.billing_account == null
    error_message = "billing_account should be null when unmanaged (manual)"
  }

  assert {
    condition     = length(google_billing_budget.budget) == 0
    error_message = "No budget should be created when billing_account is null"
  }
}

# billing_account に具体ID指定 + 予算あり: 課金リンクと予算が作られる。
run "explicit_billing_links_and_budget" {
  command = plan

  variables {
    billing_account       = "012345-6789AB-CDEF01"
    monitoring_project_id = "mgmt-proj"
    budget_amount         = 50000
    budget_alert_emails   = ["finance@example.com"]
  }

  assert {
    condition     = google_project.this.billing_account == "012345-6789AB-CDEF01"
    error_message = "billing_account should be linked to the specified account"
  }

  assert {
    condition     = length(google_billing_budget.budget) == 1
    error_message = "A budget should be created when billing_account and budget_amount are set"
  }
}
