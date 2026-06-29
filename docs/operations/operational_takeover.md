# GCP 環境 運用引き継ぎ・セットアップ手順

本書は、納品された IaC リポジトリを受け取った運用担当者が、Terraform による GCP 環境管理の運用を開始するためのセットアップ手順をまとめたものです。

______________________________________________________________________

## 1. 認証と実行権限

Terraform は管理用サービスアカウント (SA) を借用 (impersonation) して実行します。SA キー (JSON) は使用しません。

### 1.1 GCP 認証

```bash
gcloud auth login
gcloud auth application-default login
```

### 1.2 運用担当者に必要な権限

| スコープ | ロール |
| --- | --- |
| 組織 | 組織管理者 `roles/resourcemanager.organizationAdmin` |
| `*-tfstate` プロジェクト | オーナー `roles/owner` |
| Terraform 実行 SA | （自分の ID へ）`roles/iam.serviceAccountTokenCreator` |

SA の借用権限は次のように付与します（SA メールアドレス・管理プロジェクト ID は `terraform/common.tfvars` に記録されています）。

```bash
gcloud iam service-accounts add-iam-policy-binding <TF_SERVICE_ACCOUNT_EMAIL> \
  --member="user:<YOUR_EMAIL>" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="<MGMT_PROJECT_ID>"
```

### 1.3 環境との差分確認（運用開始前チェック）

```bash
make generate   # SSoT(gcp-foundations.xlsx) から Terraform の派生コードを再生成
make plan       # 差分が出なければ、現環境と IaC が一致＝そのまま運用を継続できる
```

不足している設定ファイル（`common.tfvars` / `common.tfbackend` / `domain.env` 等）がある場合は、第 3 節のリカバリガイドを参照してください。

> 受け取った zip は **Initial commit が 1 つだけのクリーンな Git リポジトリ**です（`.git` 同梱）。展開後そのまま `git log` で確認でき、ブランチ作成や自社 Git ホスティングへの push をすぐ開始できます（`git remote add origin <URL>` → `git push`）。

______________________________________________________________________

## 2. CI/CD パイプライン（GitHub Actions）の有効化（任意）

本リポジトリには、インフラの変更漏れ（ドリフト）を防ぐ自動検知や、Pull Request 時の自動 Plan を行う GitHub Actions ワークフローが標準同梱されています。自動運用を始める場合は以下を設定します。

### ① Workload Identity Federation (WIF) の構築

GitHub Actions が GCP 環境へ安全に（サービスアカウントキーなしで）アクセスするために、GCP 上に WIF プールとプロバイダを構築します。

```bash
# プロジェクトIDは tfstate バケットが存在するプロジェクト（*-tfstate-xxxx）
PROJECT_ID="<MGMT_PROJECT_ID>"
POOL_ID="github-actions-pool"
PROVIDER_ID="github-provider"
GITHUB_ORG="<自社の GitHub 組織名またはユーザー名>"

# WIF プールの作成
gcloud iam workload-identity-pools create "${POOL_ID}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# WIF プロバイダの作成
gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_ID}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${POOL_ID}" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-condition="assertion.repository_owner=='${GITHUB_ORG}'"

# プロバイダの完全なID（後続ステップで必要）
gcloud iam workload-identity-pools providers describe "${PROVIDER_ID}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${POOL_ID}" \
  --format="value(name)"
# 出力例: projects/123456789/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider

# Terraform 実行用 SA に WIF からのトークン発行を許可
SA_EMAIL="<TF_SERVICE_ACCOUNT_EMAIL>"  # common.tfvars に記録済み
POOL_RESOURCE_NAME="projects/$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/${POOL_ID}"

gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_RESOURCE_NAME}/attribute.repository/${GITHUB_ORG}/<リポジトリ名>"
```

### ② ワークフローの認証ステップを有効化

`.github/workflows/` の以下 3 つの YAML で、コメントアウトされている `Authenticate to Google Cloud` ステップ（先頭 `#` の行）を有効化します。いずれも既に `secrets.GCP_WIF_PROVIDER` / `secrets.TF_SERVICE_ACCOUNT_EMAIL` を参照する形になっているので、**コメントを外すだけ**です（書き換え不要）。

- `pr-plan.yml`（PR 時の `terraform plan`）
- `main-apply.yml`（main マージ時の `terraform apply`）
- `drift-detection.yml`（週次のドリフト検知）

### ③ GitHub Secrets の登録

GitHub リポジトリの `Settings > Secrets and variables > Actions > Secrets` に以下を登録します。このテンプレートは Actions の **Variables は使用せず、Secrets のみ**です（値は `terraform/common.tfvars` 等に記録した内容に対応）。

**WIF / 認証:**

- `GCP_WIF_PROVIDER`: ①で取得した WIF プロバイダの完全 ID
- `TF_SERVICE_ACCOUNT_EMAIL`: Terraform 実行用サービスアカウントのメールアドレス

**基盤の基本設定:**

- `GCS_BACKEND_BUCKET`: tfstate 保存用バケット名
- `ORGANIZATION_DOMAIN`: 組織ドメイン（例: example.com）
- `BILLING_ACCOUNT_ID`: 請求先アカウント ID
- `GCP_REGION`: 既定リージョン（例: asia-northeast1）
- `PROJECT_ID_PREFIX`: プロジェクト ID のプレフィックス

**機能フラグ（`true` / `false`。common.tfvars と同じ値）:**

- `ENABLE_VPC`: Shared VPC / VPC ホストプロジェクト
- `ENABLE_VPC_SC`: VPC Service Controls
- `ENABLE_ORG_POLICIES`: 組織ポリシー
- `ENABLE_TAGS`: 組織タグ
- `ENABLE_SIMPLIFIED_ADMIN_GROUPS`: 管理者グループの集約モード

> いずれの Secret も未設定時はワークフロー側の既定（ダミー値）で動作するため、**lint / validate / test / OPA などの CI は Secrets 無しでも通ります**。GCP へ実接続する plan / apply / drift（②で有効化したステップ）には上記の登録が必須です。

> **GitHub Environment**: `main-apply.yml` は `environment: production` を使用します。apply に承認者（required reviewers）やブランチ保護を掛けたい場合は `Settings > Environments` で `production` を作成・設定してください（未作成でも初回実行時に自動作成されます）。

______________________________________________________________________

## 3. 設定ファイルの復元（必要時）

環境依存ファイル（`common.tfvars` / `common.tfbackend` / `domain.env` / プロジェクト別 `terraform.tfvars` 等）が不足している場合の復元手順、および後任者への引き継ぎ手順は以下を参照してください。

- **[後任者・リカバリガイド (Recovery & Succession)](./recovery_and_succession.md)**
