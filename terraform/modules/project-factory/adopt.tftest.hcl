# project-factory: 既存プロジェクト採用(adopt)モードの回帰テスト
# `make test`（terraform test）で実行される。plan ベースで project_id の決定ロジックのみ検証する。

# CI には GCP 認証(ADC)が無いため、既存テスト(project-factory.tftest.hcl)と同様に provider をモックする。
mock_provider "google" {}

# 後方互換: create_project=true(既定) では var.project_id をそのまま使う（新規作成フローを壊さない）
run "default_uses_project_id" {
  command = plan

  variables {
    project_id      = "me-ai-foo"
    name            = "foo-dev"
    organization_id = "123456789012"
  }

  assert {
    condition     = google_project.this.project_id == "me-ai-foo"
    error_message = "create_project=true(既定) では var.project_id を採用すべき（後方互換）"
  }
}

# 採用モード: create_project=false + project_id_override で既存IDを採用する
run "adopt_uses_override" {
  command = plan

  variables {
    project_id          = "me-ai-foo"
    name                = "foo-app"
    organization_id     = "123456789012"
    create_project      = false
    project_id_override = "existing-project-1234"
  }

  assert {
    condition     = google_project.this.project_id == "existing-project-1234"
    error_message = "採用モードでは project_id_override の既存IDを採用すべき"
  }
}

# 採用モードでも override が空なら var.project_id にフォールバックする
run "adopt_empty_override_falls_back" {
  command = plan

  variables {
    project_id          = "me-ai-bar"
    name                = "bar-app"
    organization_id     = "123456789012"
    create_project      = false
    project_id_override = ""
  }

  assert {
    condition     = google_project.this.project_id == "me-ai-bar"
    error_message = "override が空なら var.project_id にフォールバックすべき"
  }
}
