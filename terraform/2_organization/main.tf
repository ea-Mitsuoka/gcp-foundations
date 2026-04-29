# 組織情報を取得
resource "terraform_data" "variable_validation" {
  input = var.enable_org_policies
}

data "google_organization" "org" {
  domain = var.organization_domain
}

# --------------------------------------------------------------------------------
# --------------------------------------------------------------------------------
# 組織ポリシー (Organization Policies) の定義
# エンタープライズ環境で必須となる強力なガバナンスベースラインを定義します。
# 移行作業や初期構築をブロックしないよう、var.enable_org_policies スイッチに連動します。
# --------------------------------------------------------------------------------

# 1. サービスアカウントキーの作成を禁止
# セキュリティ漏洩の最大の原因となるJSONキーのダウンロードを組織全体で禁止します。
# アプリケーションはWorkload Identity、人間はSAの借用(Impersonation)を利用させます。
resource "google_org_policy_policy" "disable_sa_key_creation" {
  count  = var.enable_org_policies ? 1 : 0
  name   = "organizations/${data.google_organization.org.org_id}/policies/iam.disableServiceAccountKeyCreation"
  parent = "organizations/${data.google_organization.org.org_id}"

  spec {
    rules {
      enforce = "true"
    }
  }
}

# 2. デフォルトVPCネットワークの自動作成をスキップ
# プロジェクト作成時に自動で作られる「default」ネットワークを無効化します。
# ネットワークはShared VPCホストプロジェクトで中央管理する設計を強制します。
resource "google_org_policy_policy" "skip_default_network" {
  count  = var.enable_org_policies ? 1 : 0
  name   = "organizations/${data.google_organization.org.org_id}/policies/compute.skipDefaultNetworkCreation"
  parent = "organizations/${data.google_organization.org.org_id}"

  spec {
    rules {
      enforce = "true"
    }
  }
}

# 3. 外部IPアドレスの付与を制限
# VMインスタンスが直接パブリックIPを持つことを原則禁止し、Cloud NAT等を経由させます。
# 必要に応じて、特定のプロジェクトやフォルダでExcelから例外設定を行う運用を推奨します。
resource "google_org_policy_policy" "vm_external_ip_access" {
  count  = var.enable_org_policies ? 1 : 0
  name   = "organizations/${data.google_organization.org.org_id}/policies/compute.vmExternalIpAccess"
  parent = "organizations/${data.google_organization.org.org_id}"

  spec {
    rules {
      deny_all = "true"
    }
  }
}

# --------------------------------------------------------------------------------
# 組織IAM設定 (Organization IAM)
# 管理用Googleグループに対する一元的な権限付与を行います
# --------------------------------------------------------------------------------

locals {
  # 役割ごとの標準的なロール定義
  raw_roles = {
    "gcp-organization-admins" = [
      "roles/billing.user",                      # 請求先アカウント ユーザー
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
      "roles/billing.admin",                      # 請求先アカウント管理者
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

  # 集約モード (enable_simplified_admin_groups = true) の場合のグループ構成
  # 組織管理者に請求以外の全てのロールを統合します
  simplified_group_roles = {
    "gcp-organization-admins" = distinct(flatten([
      for name, roles in local.raw_roles : roles if name != "gcp-billing-admins"
    ]))
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
  for_each = {
    for member in local.org_iam_members : "${member.group}-${member.role}" => member
  }

  org_id = data.google_organization.org.org_id
  role   = each.value.role
  member = "group:${each.value.group}@${var.organization_domain}"
}
