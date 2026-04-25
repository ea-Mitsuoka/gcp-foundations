# 新規顧客向け払い出し：初期環境セットアップ手順

## 目的

このドキュメントは、このリポジトリをテンプレートとして使用し、**全く新しい顧客のGCP組織に対して、Terraformでインフラ管理を行うための最初の基盤を構築する**手順を説明します。

作業は `terraform/scripts/setup_new_client.sh` スクリプトを実行することで、大部分が自動化されています。このスクリプトは、Terraformの状態ファイル(`.tfstate`)を保管するためのGCSバケットや、Terraform操作用のサービスアカウントなどを自動で作成します。

この手順が完了すると、`terraform/0_bootstrap`以降のTerraformコードを`apply`していく準備が整います。

______________________________________________________________________

## ステップ1: 自動セットアップスクリプトの実行

### 1a. 環境の準備

作業者のローカルPCで以下を実行します。

1. **ツールのインストール:**
   `gcloud` CLI, `terraform` CLI, `openssl`, `git`, `uv` (Pythonパッケージマネージャ) がインストールされていることを確認してください。
   ※ `uv` が未インストールの場合は `curl -LsSf https://astral.sh/uv/install.sh | sh` でインストールできます。

1. **Google Groups の事前作成 (必須):**
   `2_organization` の IAM 設定を適用するため、Google Workspace (または Cloud Identity) 上で以下のメーリングリスト（グループ）を事前に作成しておいてください。

   - `gcp-organization-admins@<顧客ドメイン>`
   - `gcp-billing-admins@<顧客ドメイン>`
   - `gcp-vpc-network-admins@<顧客ドメイン>`
   - `gcp-hybrid-connectivity-admins@<顧客ドメイン>`
   - `gcp-logging-monitoring-admins@<顧客ドメイン>`
   - `gcp-logging-monitoring-viewers@<顧客ドメイン>`
   - `gcp-security-admins@<顧客ドメイン>`
   - `gcp-devops@<顧客ドメイン>`

1. **GCPへの認証:**
   顧客のGCP組織に対して**組織管理者**などの強い権限を持つアカウントで`gcloud`にログインします。

   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

1. **リポジトリのクローン:**
   (すでにクローン済みの場合は不要です)

   ```bash
   git clone https://github.com/ea-Mitsuoka/gcp-foundations.git
   cd gcp-foundations
   ```

### 1b. スクリプトの実行

リポジトリのルートディレクトリから、以下のコマンドでスクリプトを実行します。

```bash
bash terraform/scripts/setup_new_client.sh
```

スクリプトは対話形式で以下の情報を要求します。

- **Customer's domain:** 管理対象のGCP組織に紐づくドメイン (例: `customer-domain.com`)
- **GCP region for GCS buckets:** tfstateを保管するGCSバケットを作成するリージョン (例: `asia-northeast1`)

入力後、スクリプトが作成するリソース名の一覧が表示されるので、確認して `y` を入力すると処理が開始されます。

### 1c.【手動操作】課金アカウントのリンク

スクリプトの途中で、以下のようなメッセージが表示され、一時停止します。

```text
-------------------- MANUAL ACTION REQUIRED --------------------
GCP requires an active billing account to create GCS buckets.
Please open a NEW terminal window and run the following command,
replacing <YOUR_BILLING_ID> with the actual Billing Account ID:

  gcloud billing projects link <プロジェクトID> --billing-account=<YOUR_BILLING_ID>

----------------------------------------------------------------
Press [Enter] AFTER you have successfully linked the billing account...
```

この指示に従い、**新しいターミナルを開いて**、表示されているプロジェクトIDに対して課金アカウントをリンクしてください。完了後、元のターミナルに戻り `Enter` キーを押すと、スクリプトが再開します。

スクリプトが最後まで正常に完了すれば、初期環境の構築は完了です。

______________________________________________________________________

## ステップ2: スクリプトによる自動化処理の解説 (参考)

`setup_new_client.sh` スクリプトは、以下のリソースを自動で作成・設定します。手動で操作する必要はありませんが、参考情報として記載します。

### 2a. 管理用プロジェクト

- **概要:** Terraformのtfstateファイルやサービスアカウントを管理するためだけの、専用のGCPプロジェクトを作成します。
- **命名規則:** `[組織名]-tfstate-[ランダムな接尾辞]` (例: `customer-domain-tfstate-a1b2`)
- **有効化されるAPI:**
  - `cloudresourcemanager.googleapis.com`
  - `storage.googleapis.com`
  - `iam.googleapis.com`
  - `serviceusage.googleapis.com`

### 2b. GCSバケット

- **概要:** Terraformの状態ファイル (`.tfstate`) を一元管理するためのGCSバケットを作成します。
- **設定:**
  - 均一なバケットレベルのアクセス: 有効
  - **バージョニング: 有効 (必須)**
    - 誤って状態ファイルを変更・削除しても復元できるように設定されます。

### 2c. サービスアカウント (SA)

- **概要:** TerraformがGCPリソースを操作するための専用アカウント (`terraform-org-manager`) を作成します。
- **権限付与:** このSAに対して、インフラを管理するために必要なIAMロールが付与されます。

#### **組織レベルで付与されるIAMロール:**

- `roles/resourcemanager.organizationViewer`: 組織情報を閲覧
- `roles/resourcemanager.folderAdmin`: フォルダの作成・管理
- `roles/resourcemanager.projectCreator`: プロジェクトの作成
- `roles/billing.user`: 課金アカウントの利用
- `roles/logging.admin`: ログ関連リソースの管理
- `roles/iam.securityAdmin`: IAMポリシーの管理
- `roles/serviceusage.serviceUsageAdmin`: プロジェクトでのAPI有効化
- `roles/monitoring.admin`: モニタリングの設定
- `roles/cloudasset.owner`: Cloud Asset Inventoryの管理
- `roles/browser`: GCPリソースの閲覧
- `roles/orgpolicy.policyAdmin`: 組織ポリシーの管理 (追加)

#### **その他のIAMロール:**

- **SA自身に対して:**
  - `roles/iam.serviceAccountTokenCreator`: 作業者がこのSAを借用(impersonate)することを許可
- **GCSバケットに対して:**
  - `roles/storage.objectAdmin`: SAがtfstateファイルをGCSバケットに読み書きすることを許可

______________________________________________________________________

## ステップ3: Terraformの実行準備

スクリプトによる環境構築後、実際にTerraformを実行するための設定を行います。

### 3a. バックエンド設定ファイルの作成

スクリプトの実行により、リポジトリルートの `terraform/` ディレクトリ配下に `common.tfbackend` が**自動生成**されています。中身に作成されたGCSバケット名が正しく設定されていることを確認してください。

### 3b. 変数ファイルの作成

同じく、`terraform/` ディレクトリ配下に `common.tfvars` が**自動生成**されています。Terraform操作用のサービスアカウントのメールアドレスが設定されていることを確認してください。

### 3c. Terraformの初期化

`0_bootstrap` ディレクトリに移動し、`terraform init` を実行します。
パスの設定と初期化コマンドは、運用ルールに則り以下の標準コマンドを使用します。

```bash
cd terraform/0_bootstrap

export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"

terraform init -backend-config="$(git-root)/terraform/common.tfbackend"
```

"Terraform has been successfully initialized!" と表示されれば成功です。

### 3d. `0_bootstrap`のリソースを適用

Terraform実行用のベースとなるリソース（ストレージ、API有効化、IAM設定）を順番にデプロイします。

#### 1. tfstate保存用バケットの管理化

```bash
cd "$(git rev-parse --show-toplevel)/terraform/0_bootstrap"
terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure
terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
```

#### 2. 必須APIの有効化

```bash
cd "$(git rev-parse --show-toplevel)/terraform/0_bootstrap/google_project_service"
terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure
terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
```

#### 3. TerraformサービスアカウントへのIAM権限付与

```bash
cd "$(git rev-parse --show-toplevel)/terraform/0_bootstrap/iam"
terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure
terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
```

______________________________________________________________________

## ステップ4: 基盤全体の一括デプロイ

0_bootstrap の適用が完了し、GCP上でTerraformを実行する準備（State管理や権限借用）が整いました。
最後に、残りのすべてのコアインフラ（ログ集約、監視、組織ポリシー、フォルダ作成など）を一括でデプロイします。

bash +bash terraform/scripts/deploy_all.sh +

スクリプトが成功し 🎉 All deployments completed successfully! と表示されれば、初期環境のセットアップはすべて完了です！
