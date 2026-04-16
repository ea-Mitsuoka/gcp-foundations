# 組織情報を取得
data "google_organization" "org" {
  domain = var.organization_domain
}

# --------------------------------------------------------------------------------
# 組織ポリシー (Organization Policies) の定義
# エンタープライズ環境で必須となる強力なガバナンスベースラインを適用します
# --------------------------------------------------------------------------------

# 1. サービスアカウントキーの作成を禁止
# セキュリティ漏洩の最大の原因となるJSONキーのダウンロードを組織全体で禁止します。
# アプリケーションはWorkload Identity、人間はSAの借用(Impersonation)を利用させます。
resource "google_organization_policy" "disable_sa_key_creation" {
  org_id     = data.google_organization.org.org_id
  constraint = "constraints/iam.disableServiceAccountKeyCreation"

  boolean_policy {
    enforced = true
  }
}

# 2. デフォルトVPCネットワークの自動作成をスキップ
# プロジェクト作成時に自動で作られる「default」ネットワークを無効化します。
resource "google_organization_policy" "skip_default_network" {
  org_id     = data.google_organization.org.org_id
  constraint = "constraints/compute.skipDefaultNetworkCreation"

  boolean_policy {
    enforced = true
  }
}

# 3. 外部IPアドレスの付与を制限 (必要に応じて例外を設ける運用を推奨)
# VMインスタンスが直接パブリックIPを持つことを原則禁止し、Cloud NAT等を経由させます。
resource "google_organization_policy" "vm_external_ip_access" {
  org_id     = data.google_organization.org.org_id
  constraint = "constraints/compute.vmExternalIpAccess"

  list_policy {
    deny {
      all = true
    }
  }
}
