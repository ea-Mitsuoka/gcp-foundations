# プロジェクト成方法

______________________________________________________________________

## 1. コンソールで作成する方法

GUI（グラフィカル・ユーザー・インターフェース）を使い、手動でプロジェクトを作成する最も直感的な方法です。

1. **リソースの管理画面に移動**

   - Google Cloudコンソールにログインし、[リソースの管理](https://console.cloud.google.com/cloud-resource-manager)ページを開きます。

1. **プロジェクト作成を開始**

   - 画面上部の **[プロジェクトを作成]** をクリックします。

1. **プロジェクト詳細を入力**

   - **プロジェクト名**: 人が識別しやすい名前を入力します (例: `My App (Dev)`)。
   - **請求先アカウント**: あなたの組織の請求先アカウントを選択します。
   - **組織**: あなたの組織名が表示されていることを確認します。
   - **場所**: **[参照]** をクリックし、以前Terraformで作成したフォルダ（例: `Development`）を選択します。これがプロジェクトの親になります。

1. **作成**

   - **[作成]** ボタンをクリックします。プロジェクトが作成されるまで少し待ちます。

______________________________________________________________________

## 2. gcloudコマンドで作成する方法

CLI（コマンドラインインターフェース）を使い、コマンドでプロジェクトを作成します。スクリプト化に適しています。

1. **必要なIDを環境変数に設定**

   - 事前に親となるフォルダのIDと、請求先アカウントのIDを調べておきます。

   ```bash
   # `gcloud resource-manager folders list (--organization=ORG_ID または、--folder=FOLDER_ID)` などで事前にIDを調べておく
   export FOLDER_ID="YOUR_FOLDER_ID"
   export BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1)
   ```

1. **プロジェクトを作成**

   - `gcloud projects create` コマンドで、一意のプロジェクトIDを指定して作成します。

   ```bash
   #!/bin/bash

   # プロジェクトIDはグローバルで一意である必要があります
   # ===== パラメータ（環境変数や引数でもOK） =====
   export ORG_NAME=$(gcloud organizations list --format="value(displayName)" --limit=1 | tr '.' '-')
   export ENV="dev"
   export APP="myapp"

   # ===== プロジェクトID生成 =====
   # 例: orgname-env-app
   export PROJECT_ID="${ORG_NAME}-${ENV}-${APP}"

   # ===== プロジェクト作成 =====
   gcloud projects create ${PROJECT_ID} \
     --name=${APP}-${ENV} \
     --folder="${FOLDER_ID}" \
     --impersonate-service-account=${SA_EMAIL}
   ```

   - ベストプラクティス（推奨される方法）
     - SSOTの思想に基づき、プロジェクトIDはスプレッドシート等で一元管理された「企業名・組織名 + 環境名 + アプリ名」を使用します。
     - ランダム値を排除することで、何度スクリプトを実行しても同じプロジェクト名が算出される（冪等性が保たれる）ように設計しています。

1. **課金を有効化**

   - 作成したプロジェクトを請求先アカウントにリンクします。

   ```bash
   # 課金アカウントIDを取得
   export BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1)

   # 組織レベルで請求先アカウント管理者権限を付与
   gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
     --member=user:$(gcloud config get-value account) \
     --role=roles/billing.admin

   # プロジェクトに課金アカウントをリンク
   gcloud billing projects link ${PROJECT_ID} \
     --billing-account=${BILLING_ACCOUNT_ID}
   ```

   - 上記は、組織管理者が組織レベルで請求先アカウント管理者となり、プロジェクトに対して課金アカウントをリンクさせているが、ベストプラクティスとしては以下の三者で役割分担をする
     - 組織管理者
     - 組織レベルの請求先アカウント管理者
     - プロジェクトに対して課金アカウントをリンクさせるプロジェクトオーナー
       - （課金アカウントに対する請求先アカウント管理者およびプロジェクトに対するオーナー）

______________________________________________________________________

## 3. Terraformで作成する方法（推奨）

リポジトリ (`gcp-foundations`) を使い、**Infrastructure as Code (IaC) として**プロジェクトを管理します。これが最も再現性が高く、安全な方法です。

作業は `3_projects/example_project` ディレクトリで行います。

### **ステップ1：作業ディレクトリへ移動**

```bash
cd gcp-foundations/terraform/3_projects/example_project
```

#### **`main.tf`**

変数を使い、実際にリソースを作成するコードです。

```hcl
# gcp-foundations/terraform/3_projects/example_project/main.tf
module "project" {
  source = "../../modules/project-factory"

  project_id      = "${var.project_id_prefix}-${var.environment}-${var.app_name}"
  name            = "${var.app_name}-${var.environment}"
  organization_id = data.google_organization.org.org_id
  folder_id       = var.folder_id != "" ? var.folder_id : null
  labels          = var.labels
}

resource "google_project_service" "apis" {
  for_each = var.project_apis

  project                    = module.project.project_id
  service                    = each.key
  disable_dependent_services = true
}
```

#### **`dev.tfvars`**

`dev`環境用の具体的な値を設定します。

```hcl
# gcp-foundations/terraform/3_projects/example_project/dev.tfvars
organization_name = "myorg"
app               = "myapp"

# 課金の有効化されていることが前提のAPIは有効化できない(例:compute.googleapis.com)
project_apis = [
  "storage.googleapis.com",
  "iam.googleapis.com",
]

labels = {
  env        = "dev"
  managed-by = "terraform"
}
```

### **ステップ2：Terraformを実行**

1. **Cloud Shellにログイン**: サービスアカウントの借用を設定をする

   ```bash
   cd ~/gcp-foundations/terraform/3_projects/example_project
   gcloud auth application-default login --impersonate-service-account=$SA_EMAIL
   ```

1. **初期化**:

   ```bash
   terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure
   ```

1. **プラン確認と適用**: `-var-file`フラグを使って、`dev`環境用の設定ファイルを指定します。

   ステージング環境や本番環境のプロジェクトを作成する際は、`stag.tfvars`や`prod.tfvars`を編集し、同じ手順を繰り返す

   ```bash
   terraform plan -var-file="../../common.tfvars" -var-file="dev.tfvars"
   terraform apply -var-file="../../common.tfvars" -var-file="dev.tfvars"
   ```

### **ステップ5：課金を有効化**

```bash
gcloud auth application-default revoke
gcloud auth application-default login
export PROJECT_ID=$(terraform show | grep -m1 'project_id' | awk -F'"' '{print $2}')
```

続いて[2.gcloudコマンドで作成する方法]の3.の手順に同じ
