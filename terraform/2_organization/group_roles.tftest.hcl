# 管理用 Google グループへの組織レベル IAM 付与
# （locals.group_roles → google_organization_iam_member.group_bindings）の回帰テスト。
#
# 目的: 簡略モード/フルモードのバインド件数と、簡略モードの
#       「請求(gcp-billing-admins)以外を gcp-organization-admins に集約」ロジックを固定する。
#       将来このロジックを掃除（冗長ロール削減）する際、件数差分でレビューできるようにする。
#
# CI には GCP 認証(ADC)が無いため provider をモックし、data.google_organization を override する。
# group_bindings は data.google_organization.org.org_id と変数/locals のみに依存し、
# for_each のキー集合は plan 時に確定するため、オフラインで件数を検証できる。

mock_provider "google" {}
mock_provider "google-beta" {}

override_data {
  target = data.google_organization.org
  values = {
    org_id = "123456789012"
  }
}

variables {
  organization_domain             = "example.com"
  terraform_service_account_email = "tf@example.iam.gserviceaccount.com"
  enable_vpc_sc                   = false
  enable_org_policies             = false
  enable_tags                     = false
}

# 簡略モード: org-admins = 請求以外の全ロールを重複排除(29) + billing(2) = 31 バインド
run "simplified_true_counts" {
  command = plan

  variables {
    enable_simplified_admin_groups = true
    enable_group_iam               = true
  }

  assert {
    condition     = length(google_organization_iam_member.group_bindings) == 31
    error_message = "簡略モードのバインド数は 31（org-admins 29 + billing 2）であるべき"
  }

  # セキュリティ系ロールが org-admins に集約されている（請求以外の統合）
  assert {
    condition     = contains(keys(google_organization_iam_member.group_bindings), "gcp-organization-admins-roles/securitycenter.admin")
    error_message = "簡略モードでは securitycenter.admin が org-admins に集約されるべき"
  }

  # 請求ロールは org-admins に集約しない（billing グループのみ）
  assert {
    condition     = !contains(keys(google_organization_iam_member.group_bindings), "gcp-organization-admins-roles/billing.creator")
    error_message = "billing.creator を org-admins に集約してはいけない（請求は分離）"
  }

  assert {
    condition     = contains(keys(google_organization_iam_member.group_bindings), "gcp-billing-admins-roles/billing.creator")
    error_message = "billing.creator は gcp-billing-admins に付与されるべき"
  }
}

# フルモード: 9グループのロールをグループ×ロールごとに付与 = 40 バインド
run "full_mode_counts" {
  command = plan

  variables {
    enable_simplified_admin_groups = false
    enable_group_iam               = true
  }

  assert {
    condition     = length(google_organization_iam_member.group_bindings) == 40
    error_message = "フルモードのバインド数は 40 であるべき"
  }

  assert {
    condition     = contains(keys(google_organization_iam_member.group_bindings), "gcp-security-admins-roles/securitycenter.admin")
    error_message = "フルモードでは gcp-security-admins に securitycenter.admin が付与されるべき"
  }
}

# enable_group_iam=false ではバインドを一切作らない（simplified の真偽に関わらず）
run "group_iam_off_creates_nothing" {
  command = plan

  variables {
    enable_simplified_admin_groups = true
    enable_group_iam               = false
  }

  assert {
    condition     = length(google_organization_iam_member.group_bindings) == 0
    error_message = "enable_group_iam=false ではバインドを作成してはいけない"
  }
}
