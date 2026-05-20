# 顧客への引き渡し (Handover) 手順

本ドキュメントでは、構築した GCP 基盤および IaC リポジトリを最終的に顧客（本来のインフラ管理者）へ引き渡す際の手順を説明します。

______________________________________________________________________

## 1. 納品用リポジトリの作成 (Git 履歴のリセット)

構築中の試行錯誤の履歴や、一時情報を消去するため、Git 履歴をリセットして真っ新な状態で顧客に渡します。

以下のコマンドを実行してください。

```bash
make delivery
```

このコマンドは内部的に `terraform/scripts/handover.sh` を実行し、以下の処理を行います：

1. `.git` フォルダを削除し、全ての履歴を消去します。
1. `git init` を行い、現在の最新状態で `Initial commit` を作成し直します。

実行完了後、新しく作成されたリポジトリを顧客指定の Git ホスティングサービス（GitHub, GitLab など）へ Push してください。

______________________________________________________________________

## 2. GCP 権限の移譲 (IAM)

Terraform の実行基盤（Layer 0: Bootstrap）で作成されたリソースの管理権限を顧客の管理者に移譲します。

### ステップ 1: 顧客管理者への権限付与

GCP コンソールを使用して、顧客の管理者ユーザー（または Google グループ）に対し、以下のロールを付与します。

- 組織レベル: **組織管理者** (`roles/resourcemanager.organizationAdmin`)
- `*-tfstate` プロジェクトレベル: **オーナー** (`roles/owner`)

### ステップ 2: 構築者の権限剥奪

移譲が完了し、顧客自身でコンソールアクセスや `make deploy` が実行できることを確認した後、構築者自身のアカウントの IAM バインディングを削除します。

______________________________________________________________________

## 3. 納品物の確認

引き渡し時に以下のものが揃っていることを確認してください。

1. **IaC リポジトリ**: 履歴がリセットされた最新のコード。
1. **SSoT (Excel)**: `gcp-foundations.xlsx`。現在の環境と一致していること。
1. **ドキュメント**: 本 `docs/` ディレクトリ配下のマニュアル一式。

______________________________________________________________________

## 4. CI/CDパイプライン（GitHub Actions）の有効化案内

本テンプレートには、インフラの変更漏れ（ドリフト）を防ぐための自動検知機能や、Pull Request時の自動Plan機能が標準搭載されています。
顧客が自身の環境でこれらを有効化し、IaCの自動運用を開始できるよう、以下のセットアップ手順を案内してください。

### ① Workload Identity Federation (WIF) の構築

GitHub Actions が GCP 環境へ安全に（サービスアカウントキーなしで）アクセスするために、GCP 上に WIF プールとプロバイダを構築します。以下の手順を案内してください。

```bash
# プロジェクトIDは tfstate バケットが存在するプロジェクト（*-tfstate-xxxx）
PROJECT_ID="<MGMT_PROJECT_ID>"
POOL_ID="github-actions-pool"
PROVIDER_ID="github-provider"
GITHUB_ORG="<顧客のGitHub組織名またはユーザー名>"

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

顧客環境の `.github/workflows/` 配下にある以下の YAML ファイルについて、`Authenticate to Google Cloud` ステップのコメントアウト（`#`）を外し、①で取得した WIF プロバイダ完全IDと、Terraform 実行用サービスアカウントのメールアドレスを設定します。

- `drift-detection.yml` — `secrets.GCP_WIF_PROVIDER` と `secrets.TF_SERVICE_ACCOUNT_EMAIL` を参照するよう記載済み
- `main-apply.yml`
- `pr-plan.yml` — ハードコードされたサンプル値が記載されているため、Secrets 参照形式（`${{ secrets.GCP_WIF_PROVIDER }}`）に書き換えること

### ③ GitHub Secrets の登録

顧客の GitHub リポジトリの `Settings > Secrets and variables > Actions` にて、以下の環境変数を登録するよう案内します。
（※これらは構築時に使用した `terraform/common.tfvars` に記録されている値に相当します）

- `GCP_WIF_PROVIDER`: ①で取得した WIF プロバイダの完全ID
- `GCS_BACKEND_BUCKET`: tfstate保存用バケット名
- `TF_SERVICE_ACCOUNT_EMAIL`: Terraform実行用サービスアカウントのメールアドレス
- `ORGANIZATION_DOMAIN`: 組織ドメイン（例: example.com）
- `BILLING_ACCOUNT_ID`: 請求先アカウントID
- `PROJECT_ID_PREFIX`: プロジェクトIDのプレフィックス
- `ENABLE_VPC`, `ENABLE_VPC_SC` などの各種フラグ (true/false)

______________________________________________________________________

## 5. 後任者によるセットアップ

リポジトリを受け取った後任の開発者は、そのままでは Terraform を実行できません（環境依存の設定ファイルが Git 管理外のため）。
受け取り後の環境復元手順については、以下のガイドを必ず参照してください。

- **[後任者・リカバリガイド (Recovery & Succession)](./recovery_and_succession.md)**

このガイドには、不足している `tfvars` や `backend` 設定の復元方法、権限の借用手順などが記載されています。
