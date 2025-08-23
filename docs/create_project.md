# プロジェクト成方法

-----

## 1. コンソールで作成する方法

GUI（グラフィカル・ユーザー・インターフェース）を使い、手動でプロジェクトを作成する最も直感的な方法です。

1. **リソースの管理画面に移動**

      * Google Cloudコンソールにログインし、[リソースの管理](https://console.cloud.google.com/cloud-resource-manager)ページを開きます。

2. **プロジェクト作成を開始**

      * 画面上部の **[プロジェクトを作成]** をクリックします。

3. **プロジェクト詳細を入力**

      * **プロジェクト名**: 人が識別しやすい名前を入力します (例: `My App (Dev)`)。
      * **請求先アカウント**: あなたの組織の請求先アカウントを選択します。
      * **組織**: あなたの組織名が表示されていることを確認します。
      * **場所**: **[参照]** をクリックし、以前Terraformで作成したフォルダ（例: `Development`）を選択します。これがプロジェクトの親になります。

4. **作成**

      * **[作成]** ボタンをクリックします。プロジェクトが作成されるまで少し待ちます。

-----

## 2. gcloudコマンドで作成する方法

CLI（コマンドラインインターフェース）を使い、コマンドでプロジェクトを作成します。スクリプト化に適しています。

1. **必要なIDを環境変数に設定**

      * 事前に親となるフォルダのIDと、請求先アカウントのIDを調べておきます。

    ```bash
    # `gcloud resource-manager folders list (--organization=ORG_ID または、--folder=FOLDER_ID)` などで事前にIDを調べておく
    export FOLDER_ID="YOUR_FOLDER_ID"
    export BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1)
    ```

2. **プロジェクトを作成**

      * `gcloud projects create` コマンドで、一意のプロジェクトIDを指定して作成します。

    ```bash
    #!/bin/bash

    # プロジェクトIDはグローバルで一意である必要があります
    # ===== パラメータ（環境変数や引数でもOK） =====
    export ORG_NAME=$(gcloud organizations list --format="value(displayName)" --limit=1 | tr '.' '-')
    export ENV="dev"
    export APP="myapp"

    # ===== ランダム4桁の16進数を生成 =====
    export SUFFIX=$(openssl rand -hex 2)   # Terraformの random_id.byte_length=2 と同じ

    # ===== プロジェクトID生成 =====
    # 例: orgname-env-app-xxxx （xxxxは16進数4桁のランダム）
    export PROJECT_ID="${ORG_NAME}-${ENV}-${APP}-${SUFFIX}"

    # ===== プロジェクト作成 =====
    gcloud projects create ${PROJECT_ID} \
      --name=${APP}-${ENV} \
      --folder="${FOLDER_ID}" \
      --impersonate-service-account=${SA_EMAIL}
    ```

      * ベストプラクティス（推奨される方法）
        * 一意性の担保は「命名規約＋短いランダム suffix」で行う
          * 「企業名・組織名 + 環境名 + アプリ名 + 短いランダム」のような形式。
        * 「衝突可能性をゼロにする」ことよりも、運用で識別できる意味のある ID を優先。
        * 一意性を完全にランダムで担保すると、可読性が落ち運用負荷が上がる。

3. **課金を有効化**

      * 作成したプロジェクトを請求先アカウントにリンクします。

    ```bash
    # 組織レベルで請求先アカウント管理者権限を付与
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member=user:$(gcloud config get-value account) \
      --role=roles/billing.admin

    # プロジェクトに課金アカウントをリンク
    gcloud billing projects link ${PROJECT_ID} \
      --billing-account=${BILLING_ACCOUNT_ID}
    ```

    * 上記は、組織管理者が組織レベルで請求先アカウント管理者となり、プロジェクトに対して課金アカウントをリンクさせているが、ベストプラクティスとしては以下の三者で役割分担をする
      * 組織管理者
      * 組織レベルの請求先アカウント管理者
      * プロジェクトに対して課金アカウントをリンクさせるプロジェクトオーナー
        * （課金アカウントに対する請求先アカウント管理者およびプロジェクトに対するオーナー）

-----

## 3. Terraformで作成する方法（推奨）

リポジトリ (`gcp-foundations`) を使い、**Infrastructure as Code (IaC) として**プロジェクトを管理します。これが最も再現性が高く、安全な方法です。

作業は `3_projects/example_project` ディレクトリで行います。

### **ステップ1：作業ディレクトリへ移動**

```bash
cd gcp-foundations/terraform/3_projects/example_project
```

### **ステップ2：ファイルの内容を定義**

各ファイルに、プロジェクトを作成するためのコードを記述します。

#### **`versions.tf`**

```hcl
# gcp-foundations/terraform/3_projects/example_project/versions.tf
terraform {
    # "~>" を使い、意図しないメジャー/マイナーアップデートを防ぎます
    required_version = "~> 1.12.2"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

#### **`backend.tf`**

`dev`環境用のtfstateが、他の環境と分離されるように`prefix`を設定します。

```hcl
# gcp-foundations/terraform/3_projects/example_project/backend.tf
terraform {
  backend "gcs" {
    # このディレクトリ用のtfstateの保存場所を区別するためのprefix
    prefix = "projects/dev"
  }
}
```

#### **`provider.tf`**

この設定により、Terraform実行時に自動でSAを借用します

```hcl
provider "google" {
  impersonate_service_account = var.terraform_service_account_email
}
```

#### **`variables.tf`**

この「プロジェクト工場」が必要とする変数を定義します。

```hcl
# gcp-foundations/terraform/3_projects/example_project/variables.tf
variable "organization_name" {
  type        = string
  description = "組織の名前（project_id 生成用に正規化する）。"
}

variable "organization_id" {
  type        = string
  description = "作成するGCPプロジェクトが属する組織のID。"
}

variable "terraform_service_account_email" {
  type        = string
  description = "TerraformがGCP操作用に借用するサービスアカウントのメールアドレス。"
}

variable "folder_path" {
  type        = string
  default     = ""
  description = "プロジェクトを作成するフォルダのパス。空文字なら組織直下"
}

variable "billing_account_id" {
  type        = string
  description = "紐付ける請求先アカウントのID。"
}

variable "project_apis" {
  type        = set(string)
  description = "プロジェクトで有効化するAPIのリスト。"
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "プロジェクトに付与するラベル。"
  default     = {}
}
```

#### **`main.tf`**

変数を使い、実際にリソースを作成するコードです。

```hcl
# gcp-foundations/terraform/3_projects/example_project/main.tf
module "string_utils" {
  source            = "gitea.mtskykhd.tokyo/admin/terraform-modules.git"
  organization_name = var.organization_name
  env               = var.labels.env
  app               = var.labels.app
}

resource "random_id" "project_suffix" {
  byte_length = 2
}

locals {
  folder_id = var.folder_path != "" ? var.folder_path : null
}

resource "google_project" "main" {
  project_id      = "${module.string_utils.sanitized_org_name}-${module.string_utils.sanitized_env}-${module.string_utils.sanitized_app}-${random_id.project_suffix.hex}"
  name            = "${var.labels.app}-${var.labels.env}"
  billing_account = var.billing_account_id
  labels          = var.labels

  org_id    = local.folder_id == null ? var.organization_id : null
  folder_id = local.folder_id # folder_id が null なら無視され、組織直下に作成される
}

resource "google_project_service" "apis" {
  for_each = var.project_apis

  project                    = google_project.main.project_id
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

project_apis = [
  "compute.googleapis.com",
  "storage.googleapis.com",
  "iam.googleapis.com",
]

labels = {
  env        = "dev"
  managed-by = "terraform"
}
```

TODO: 書き直す
### **ステップ3: 環境変数でTerraformに変数を渡す**

`terraform.tfvars`ファイルの他に秘匿情報はターミナルで以下のコマンドを実行し、Terraformが自動で読み込む環境変数を設定します。

```bash
# Terraformが読み取れる形式の環境変数に設定します。
export TF_VAR_organization_id=$ORGANIZATION_ID
export TF_VAR_terraform_service_account_email=$SA_EMAIL
export TF_VAR_billing_account_id=$BILLING_ACCOUNT_ID

# 設定されたか確認
echo $TF_VAR_organization_id
echo $TF_VAR_terraform_service_account_email
echo $TF_VAR_billing_account_id

# プロジェクトをフォルダ配下に作る場合のみ定義
export TF_VAR_folder_path=$FOLDER_ID
echo $TF_VAR_folder_path
```

### **ステップ4：Terraformを実行**

1. **Cloud Shellにログイン**: サービスアカウントの借用を設定をする

    ```bash
    gcloud auth application-default login --impersonate-service-account="$SERVICE_ACCOUNT_EMAIL"
    ```

2. **初期化**:

    ```bash
    terraform init -backend-config="bucket=${BUCKET_NAME}"

    # -reconfigureオプションは、設定変更時に役立ちます
    terraform init \
      -reconfigure \
      -backend-config="bucket=${BUCKET_NAME}"
    ```

3. **プラン確認と適用**: `-var-file`フラグを使って、`dev`環境用の設定ファイルを指定します。

    ```bash
    terraform plan -var-file="dev.tfvars"
    terraform apply -var-file="dev.tfvars"
    ```

これで、コードとしてバージョン管理された、再現可能な形でプロジェクトが作成されます。ステージング環境や本番環境のプロジェクトを作成する際は、`stag.tfvars`や`prod.tfvars`を編集し、同じ手順を繰り返すだけです。
