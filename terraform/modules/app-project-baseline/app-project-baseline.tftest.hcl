mock_provider "google" {}
mock_provider "google-beta" {}

# google_organization データソースをモック
override_data {
  target = data.google_organization.org
  values = {
    org_id = "123456789012"
  }
}

# terraform_remote_state (folders) をモック
# folder_id を直接指定する場合でも Terraform がデータソースを評価するためモックが必要
override_data {
  target = data.terraform_remote_state.folders
  values = {
    outputs = {}
  }
}

variables {
  organization_domain             = "example.com"
  gcs_backend_bucket              = "test-tfstate-bucket"
  project_id_prefix               = "test"
  app_name                        = "test-app"
  environment                     = "dev"
  terraform_service_account_email = "terraform@test-project.iam.gserviceaccount.com"
  folder_id                       = null
  enable_shared_vpc               = false
  enable_vpc_sc                   = false
  enable_tags                     = false
  central_monitoring              = false
  central_logging                 = false
  deletion_protection             = false
}

# 最小構成でのプランが成功することを確認
run "minimal_config_plan_succeeds" {
  command = plan
}

# 各フィーチャーフラグが false のときにオプショナルリソースが生成されないことを確認
run "optional_resources_absent_when_disabled" {
  command = plan

  assert {
    condition     = length(google_project_service.compute_api) == 0
    error_message = "Compute API should not be enabled when enable_shared_vpc=false"
  }

  assert {
    condition     = length(google_compute_shared_vpc_service_project.service_project) == 0
    error_message = "Shared VPC service project should not be created when enable_shared_vpc=false"
  }

  assert {
    condition     = length(google_monitoring_monitored_project.central_monitoring_registration) == 0
    error_message = "Central monitoring should not be registered when central_monitoring=false"
  }
}
