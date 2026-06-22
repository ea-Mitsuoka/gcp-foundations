# 顧客への引き渡し (Handover) 手順

本ドキュメントでは、構築した GCP 基盤および IaC リポジトリを最終的に顧客（本来のインフラ管理者）へ引き渡す際の手順を説明します。

______________________________________________________________________

## 1. 納品成果物の作成 (make delivery)

`make delivery` を実行すると、**元リポジトリ（`.git`・作業ツリー）には一切手を加えず**、一時コピー上でクリーンな Git ツリーを作成し、`delivery/` 配下に納品成果物を出力します。

```bash
make delivery
```

内部処理：

1. `terraform/scripts/generate_delivery.py` が構築設定明細書を `delivery/GCP基盤構築_設定明細書_<YYYYMMDD>.xlsx` として生成します（前段。詳細は「6. 納品物（構築設定明細書）の自動生成」）。
1. `terraform/scripts/handover.sh` が作業ツリーを一時領域へコピーし、`.gitignore` を納品用に調整したうえで `git init` → `commit` → `git archive` を実行し、`delivery/gcp-foundations_<YYYYMMDD>.zip` を出力します。**元の `.git` は保持されます。**

> 旧版のように `.git` を削除して履歴を作り直すことはしません（誤実行による事故防止）。**本番の作業リポジトリでそのまま実行して問題ありません。**

顧客へは `delivery/` 配下の**2ファイル**を提供します（zip に明細書 xlsx は含まれません。別ファイルとして渡します）：

- `GCP基盤構築_設定明細書_<YYYYMMDD>.xlsx`（構築設定明細書）
- `gcp-foundations_<YYYYMMDD>.zip`（IaC 一式。下記方針でファイルを取捨選択済み）

### 納品 zip に含まれるもの／含まれないもの

**含む（顧客が環境を再現・運用するために必要）:**

- IaC テンプレート一式、自動生成コード（`auto_*.tf`）
- 環境固有のソース設定：`terraform/common.tfvars`、`terraform/common.tfbackend`、`domain.env`、`gcp-foundations.xlsx`
- 運用ドキュメント：`docs/setup/`、`docs/operations/`（一部除く）、`docs/reference/`、`docs/design/`（architecture / data-dictionary / iam_management_scope）

**含まない（社内限定・顧客の運用には不要）:**

- `docs/development/`、`docs/tests/`、`docs/ea-design/`、`docs/migration/`
- `docs/design/todo.md`、`docs/design/generator_philosophy.md`
- `docs/operations/module_maintenance.md`、`delivery_document_generation.md`、`spreadsheet_session_guide.md`
- `tfstate`、ローカルキャッシュ（`.terraform/` 等）、`.venv`、構築設定明細書（xlsx は zip とは別に提供）

### 顧客側での受け取り後の確認（運用引き継ぎ）

顧客は zip 展開後、以下で「環境に差分が無い」ことを確認して Terraform 管理の運用を引き継げます。

```bash
# 認証（顧客の管理者アカウントで）
gcloud auth login
gcloud auth application-default login

# SSoT(xlsx) から派生コードを再生成し、現環境との差分を確認
make generate
make plan          # 差分が出なければ、現環境と IaC が一致＝引き継ぎ可能
```

> `make generate` は `gcp-foundations.xlsx` から `terraform/4_projects/<project>/` 等の派生コードを再生成します（GCP には接続しません）。`make plan` の成功には「2. GCP 権限の移譲」（TF 実行 SA へのインパーソネーション権限・tfstate バケットへのアクセス）が前提です。

顧客が自身の Git ホスティング（GitHub / GitLab 等）で管理を始める場合は、展開したディレクトリで `git init` → 初回コミット → push してください（`git archive` は履歴を含まないため）。

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

1. **IaC 一式 (zip)**: `gcp-foundations_<YYYYMMDD>.zip`。社内限定ドキュメント・tfstate・キャッシュを除外済み。
1. **構築設定明細書**: `GCP基盤構築_設定明細書_<YYYYMMDD>.xlsx`（zip とは別ファイル）。
1. **SSoT (Excel)**: `gcp-foundations.xlsx`（zip に同梱）。現在の環境と一致していること。
1. **ドキュメント**: zip 内 `docs/` の運用マニュアル一式（社内限定分は除外済み）。

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

______________________________________________________________________

## 6. 納品物（構築設定明細書）の自動生成

`make delivery` 実行時（または単体で `make delivery-doc`）、SSoT である `gcp-foundations.xlsx` と `terraform/common.tfvars` / `domain.env` を読み取り、日本のシステム開発における一般的な「設計・設定明細書」様式の Excel を `delivery/GCP基盤構築_設定明細書_<YYYYMMDD>.xlsx` として自動生成します（生成スクリプト: `terraform/scripts/generate_delivery.py`）。

シート構成・判定ロジック・表紙メタ情報の上書き方法など、機能の詳細は以下を参照してください。

- **[納品物（構築設定明細書）自動生成 機能説明](./delivery_document_generation.md)**

> `delivery/` はテンプレートリポジトリでは `.gitignore` 対象（顧客固有データを含むため）ですが、`handover.sh` が除外を解除するため、顧客への納品リポジトリ（`make delivery` 後の `Initial commit`）には同梱されます。
