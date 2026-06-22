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

> 受け取った zip には Git 履歴が含まれません。バージョン管理を始める場合は、展開したディレクトリで `git init` → 初回コミット → 自社の Git ホスティングへ push してください。

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

### ② ワークフローのコメントアウト解除

`.github/workflows/` 配下の以下の YAML について、`Authenticate to Google Cloud` ステップのコメントアウト（`#`）を外し、①で取得した WIF プロバイダ完全 ID と Terraform 実行用サービスアカウントのメールアドレスを設定します。

- `drift-detection.yml` — `secrets.GCP_WIF_PROVIDER` と `secrets.TF_SERVICE_ACCOUNT_EMAIL` を参照するよう記載済み
- `main-apply.yml`
- `pr-plan.yml` — ハードコードされたサンプル値が記載されているため、Secrets 参照形式（`${{ secrets.GCP_WIF_PROVIDER }}`）に書き換えること

### ③ GitHub Secrets の登録

GitHub リポジトリの `Settings > Secrets and variables > Actions` にて、以下を登録します（値は `terraform/common.tfvars` に記録されている内容に相当します）。

- `GCP_WIF_PROVIDER`: ①で取得した WIF プロバイダの完全 ID
- `GCS_BACKEND_BUCKET`: tfstate 保存用バケット名
- `TF_SERVICE_ACCOUNT_EMAIL`: Terraform 実行用サービスアカウントのメールアドレス
- `ORGANIZATION_DOMAIN`: 組織ドメイン（例: example.com）
- `BILLING_ACCOUNT_ID`: 請求先アカウント ID
- `PROJECT_ID_PREFIX`: プロジェクト ID のプレフィックス
- `ENABLE_VPC`, `ENABLE_VPC_SC` などの各種フラグ (true/false)

______________________________________________________________________

## 3. 設定ファイルの復元（必要時）

環境依存ファイル（`common.tfvars` / `common.tfbackend` / `domain.env` / プロジェクト別 `terraform.tfvars` 等）が不足している場合の復元手順、および後任者への引き継ぎ手順は以下を参照してください。

- **[後任者・リカバリガイド (Recovery & Succession)](./recovery_and_succession.md)**
