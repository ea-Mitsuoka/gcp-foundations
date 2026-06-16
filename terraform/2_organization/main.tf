# 組織情報を取得
resource "terraform_data" "variable_validation" {
  input = [
    var.enable_org_policies,
    var.enable_tags
  ]
}

data "google_organization" "org" {
  domain = var.organization_domain
}

# --------------------------------------------------------------------------------
# 組織IAM設定 (Organization IAM)
# 管理用Googleグループに対する一元的な権限付与を行います
# --------------------------------------------------------------------------------

locals {
  # 役割ごとの標準的なロール定義
  raw_roles = {
    "gcp-organization-admins" = [
      "roles/cloudkms.admin",                    # クラウド KMS 管理者
      "roles/cloudsupport.admin",                # サポート アカウント管理者
      "roles/iam.organizationRoleAdmin",         # 組織のロールの管理者
      "roles/orgpolicy.policyAdmin",             # 組織ポリシー管理者
      "roles/pubsub.admin",                      # Pub/Sub 管理者
      "roles/resourcemanager.folderAdmin",       # フォルダ管理者
      "roles/resourcemanager.organizationAdmin", # 組織管理者
      "roles/resourcemanager.projectCreator",    # プロジェクト作成者
      "roles/securitycenter.admin",              # セキュリティ センター管理者
    ]
    "gcp-billing-admins" = [
      "roles/billing.creator",                    # 請求先アカウント作成者
      "roles/resourcemanager.organizationViewer", # 組織閲覧者
    ]
    "gcp-vpc-network-admins" = [
      "roles/compute.networkAdmin",         # Compute ネットワーク管理者
      "roles/compute.securityAdmin",        # Compute セキュリティ管理者
      "roles/compute.xpnAdmin",             # Compute Shared VPC 管理者
      "roles/resourcemanager.folderViewer", # フォルダ閲覧者
    ]
    "gcp-hybrid-connectivity-admins" = [
      "roles/compute.networkAdmin",         # Compute ネットワーク管理者
      "roles/resourcemanager.folderViewer", # フォルダ閲覧者
    ]
    "gcp-logging-monitoring-admins" = [
      "roles/logging.admin",    # Logging 管理者
      "roles/monitoring.admin", # モニタリング管理者
      "roles/pubsub.admin",     # Pub/Sub 管理者
    ]
    "gcp-logging-monitoring-viewers" = [
      "roles/logging.viewer",    # ログ閲覧者
      "roles/monitoring.viewer", # モニタリング閲覧者
    ]
    "gcp-security-admins" = [
      "roles/cloudkms.admin",                 # クラウド KMS 管理者
      "roles/compute.viewer",                 # Compute 閲覧者
      "roles/container.viewer",               # Kubernetes Engine 閲覧者
      "roles/iam.organizationRoleViewer",     # 組織のロールの閲覧者
      "roles/iam.securityAdmin",              # セキュリティ管理者
      "roles/iam.securityReviewer",           # セキュリティ審査担当者
      "roles/iam.serviceAccountCreator",      # サービス アカウントの作成
      "roles/logging.admin",                  # Logging 管理者
      "roles/logging.configWriter",           # ログ構成書き込み
      "roles/logging.privateLogViewer",       # プライベート ログ閲覧者
      "roles/monitoring.admin",               # モニタリング管理者
      "roles/orgpolicy.policyAdmin",          # 組織ポリシー管理者
      "roles/resourcemanager.folderIamAdmin", # フォルダ IAM 管理者
      "roles/securitycenter.admin",           # セキュリティ センター管理者
    ]
    "gcp-developers" = [
      "roles/browser",                            # ブラウザ
      "roles/viewer",                             # 閲覧者
      "roles/resourcemanager.organizationViewer", # 組織閲覧者
    ]
    "gcp-devops" = [
      "roles/resourcemanager.folderViewer", # フォルダ閲覧者
    ]
  }

  # 簡略モードで gcp-organization-admins から除外する「冗長ロール」。
  # 付与しても権限は増えず（同サービスの admin か基本ロール roles/viewer に包含される）、
  # 監査ノイズと保守コストになるだけのもの。包含関係:
  #   - logging.admin                     ⊇ logging.viewer / logging.configWriter / logging.privateLogViewer
  #   - monitoring.admin                  ⊇ monitoring.viewer
  #   - resourcemanager.folderAdmin       ⊇ folderViewer / folderIamAdmin
  #   - resourcemanager.organizationAdmin ⊇ organizationViewer
  #   - iam.organizationRoleAdmin         ⊇ organizationRoleViewer
  #   - 基本ロール roles/viewer            ⊇ browser / compute.viewer / container.viewer
  # 注: iam.securityReviewer は横断的な getIamPolicy を持ち securityAdmin にも roles/viewer にも
  #     包含されないため、ここには含めず残す。
  simplified_redundant_roles = [
    "roles/logging.viewer",
    "roles/logging.configWriter",
    "roles/logging.privateLogViewer",
    "roles/monitoring.viewer",
    "roles/resourcemanager.folderViewer",
    "roles/resourcemanager.folderIamAdmin",
    "roles/resourcemanager.organizationViewer",
    "roles/iam.organizationRoleViewer",
    "roles/browser",
    "roles/compute.viewer",
    "roles/container.viewer",
  ]

  # 集約モード (enable_simplified_admin_groups = true) の場合のグループ構成。
  # 組織管理者に請求(gcp-billing-admins)以外の全ロールを統合しつつ、上記の冗長ロールを除外する。
  simplified_group_roles = {
    "gcp-organization-admins" = [
      for r in distinct(flatten([
        for name, roles in local.raw_roles : roles if name != "gcp-billing-admins"
      ])) : r if !contains(local.simplified_redundant_roles, r)
    ]
    "gcp-billing-admins" = local.raw_roles["gcp-billing-admins"]
  }

  # フラグに応じて使用するマップを選択
  group_roles = var.enable_simplified_admin_groups ? local.simplified_group_roles : local.raw_roles

  # リソース展開用に「グループ名とロールの組み合わせ」を平坦化（flatten）したリストを作成
  org_iam_members = flatten([
    for group, roles in local.group_roles : [
      for role in roles : {
        group = group
        role  = role
      }
    ]
  ])
}

resource "google_organization_iam_member" "group_bindings" {
  for_each = var.enable_group_iam ? {
    for member in local.org_iam_members : "${member.group}-${member.role}" => member
  } : {}

  org_id = data.google_organization.org.org_id
  role   = each.value.role
  member = "group:${each.value.group}@${var.organization_domain}"
}
