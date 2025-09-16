# 最初の環境構築手順

## 事前準備

1. 課金の画面で課金アカウント作成
2. Google Cloudのリソース管理画面でプロジェクトを作成をクリック
3. 希望のプロジェクト名を入力すると自動で一意のproject_idが下部に提案されるため、それをコピー

-----

## 概要：これから行うこと

1. **管理用プロジェクトの作成**: Terraformの実行拠点となる、専用のGCPプロジェクトを作成します。
2. **GCSバケットの作成**: Terraformの状態ファイル（`.tfstate`）を安全に保管する場所（GCSバケット）を作ります。
3. **サービスアカウントの作成**: TerraformがGCPリソースを操作するための専用IDを作成し、組織を管理できる権限を付与します。
4. **Terraformファイルの準備**: GCSバケットをバックエンドとして設定する、最初のTerraformファイルを作成し、初期化します。

-----

### 前提条件

* `gcloud` CLIがインストールされ、組織管理者権限を持つアカウントでログイン済みであること。
  * `gcloud auth login`
  * `gcloud config set account 'YOUR_ADMIN_ACCOUNT@example.com'`
* `terraform` CLIがインストール済みであること。

-----

### ステップ1: 環境変数の設定と情報取得

まず、作業に必要な情報を取得し、後のコマンドで使いやすいように環境変数に設定します。

1. **domain.envを定義**

    ```bash
    git clone https://github.com/ea-Mitsuoka/gcp-foundations.git
    cd gcp-foundations
    cat > domain.env << 'EOF'
    domain="my-domain.com"
    EOF
    ```

1. **組織IDを取得して設定**

    ```bash
    source ./domain.env
    export ORGANIZATION_ID=$(gcloud organizations list --filter="displayName=\"$domain\"" --format="value(ID)")
    echo $ORGANIZATION_ID
    ```

1. **請求先アカウントIDを取得して設定**
    1. Google Cloudコンソールの課金の画面で課金アカウントを作成する

    ```bash
    gcloud billing accounts list
    export BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1)
    echo $BILLING_ACCOUNT_ID
    ```

1. **作成するプロジェクトIDとバケット名を決めて設定**
    1. Google Cloudのリソース管理画面でプロジェクトを作成をクリック
       1. これから作成するのは最初のtfstateファイルを管理する専用のプロジェクトで、おすすめの命名規則は以下の通り
          1. myorg-tf-admin(Terraformの管理者用プロジェクトであることが明確)
          2. myorg-iac-admin(Terraformだけでなく、IaC全般の管理者用プロジェクトという広い意味を持つ)
          3. myorg-tf-mgmt(adminの代わりにmgmt (management) を使うパターン)
    2. 希望のプロジェクト名を入力すると自動で一意のproject_idが下部に提案されるため、それをコピーするか、以下のコマンドで一意になるように生成する

    ```bash
    # プロジェクトIDはグローバルで一意である必要があります
    export SUFFIX=$(openssl rand -hex 2) 
    export ORG_NAME=$(echo "$domain" | tr '.' '-')
    export PROJECT_ID="${ORG_NAME}-tf-admin-${SUFFIX}"
    export PROJECT_NAME="${ORG_NAME}-tf-admin"

    # バケット名を生成するshellファイルを実行
    bash ./generate-backend-config.sh
    # 生成されたファイルからバケット名を取得
    export BUCKET_NAME="$(grep "bucket" ./terraform/common.tfbackend | cut -d '"' -f 2)"

    echo "作成するプロジェクト名: ${PROJECT_NAME}"
    echo "作成するプロジェクトID: ${PROJECT_ID}"
    echo "作成するGCSバケット名: ${BUCKET_NAME}"
    ```

1. **今後必要なIAM権限を付与する** #省略可

    ```bash
    # 組織レベルでログ閲覧者ロールを付与
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member=user:$(gcloud config get-value account) \
      --role="roles/logging.viewer"

    # 組織ポリシー管理者ロールを付与
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member=user:$(gcloud config get-value account) \
      --role="roles/orgpolicy.policyAdmin"
    ```

-----

### ステップ2: 管理用プロジェクトの作成

Terraformの実行拠点となるプロジェクトを作成し、APIを有効化します。

1. **プロジェクトを作成**

    ```bash
    gcloud projects create ${PROJECT_ID} \
      --name=${PROJECT_NAME} \
      --organization=${ORGANIZATION_ID}
    ```

   1. コマンドでプロジェクトを作成すると`gcloud projects list`コマンドでプロジェクトが作成されているのを確認できるのに、Google Cloudのダッシュボードにアクセスしてもプロジェクトが表示されないことがある。
      1. 上記のような場合以下のURLにブラウザでアクセスする

      ```text
      https://console.cloud.google.com/home/dashboard?project=${PROJECT_ID}
      ```

2. **プロジェクトに課金をリンク**

    ```bash
    gcloud billing projects link ${PROJECT_ID} \
      --billing-account=${BILLING_ACCOUNT_ID}
    ```

    * 失敗した場合、プロジェクトに対してオーナー権限と課金アカウントに対して請求先アカウント管理者権限を付与する

3. **プロジェクトで必要なAPIを有効化**
    （少し時間がかかる場合があります）

    ```bash
    gcloud services enable \
      cloudresourcemanager.googleapis.com \
      storage.googleapis.com \
      iam.googleapis.com \
      serviceusage.googleapis.com \
      --project=${PROJECT_ID}
    ```

-----

### ステップ3: GCSバケットの作成

Terraformの状態ファイル（`.tfstate`）を保管するGCSバケットを作成します。

  ```bash
  # バケット作成
  gcloud storage buckets create gs://${BUCKET_NAME} \
    --project=${PROJECT_ID} \
    --location="asia-northeast1" \
    --uniform-bucket-level-access

  # バージョニングの有効化
  gsutil versioning set on gs://${BUCKET_NAME}
  ```

* `--location`: バケットのリージョンです。東京 (`asia-northeast1`) などを指定します。
* `gsutil versioning set`: **非常に重要**です。誤って状態ファイルを変更・削除してしまっても復元できるように、必ず有効にします。

-----

### ステップ4: サービスアカウントの作成と権限設定

Terraformが組織リソースを操作するための「ロボットアカウント」を作成します。

1. **サービスアカウント本体を作成**

    ```bash
    export SA_NAME="terraform-org-manager"
    export SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

    gcloud iam service-accounts create ${SA_NAME} \
      --display-name="Terraform Organization Manager" \
      --project=${PROJECT_ID}
    ```

1. **サービスアカウントに組織レベルの権限を付与**

    組織リソースを管理するため、強力な権限を付与します。</br>
    サービスアカウント自体はプロジェクトに作成しているのに組織レベルの権限を付与してあり、付与した権限をIAM画面で確認するのも組織レベルである必要があります。

    ```bash
    # 組織の閲覧者、フォルダ管理者、プロジェクト作成者の権限を付与
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="roles/resourcemanager.organizationViewer"

    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="roles/resourcemanager.folderAdmin"

    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="roles/resourcemanager.projectCreator"

    # 課金アカウントの利用権限も付与
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="roles/billing.user"

    # ログ集約シンクプロジェクトを設定するのにログ設定管理者を付与
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="roles/logging.admin"

    # IAMの一括管理のためセキュリティ管理者を付与
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="roles/iam.securityAdmin"

    # APIの有効化のためにService Usage 管理者を付与
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="roles/serviceusage.admin"

    # スコープ対象のプロジェクトをモニタリングするためにを付与
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="roles/monitoring.viewer"
    ```

    > **セキュリティ**: ここでは一般的な権限を付与していますが、要件に応じて[最小権限の原則](https://www.google.com/search?q=https://cloud.google.com/iam/docs/using-iam-securely%3Fhl%3Dja%23least_privilege)に従い、より厳密なロールを選択してください。

1. **サービスアカウントにプロジェクトレベルの権限を付与**

   あなたのユーザーアカウント (gcloudにログインしているアカウント) が、作成したサービスアカウントを借用する（成り代わる）ことを許可する必要があります。

    ```bash
    gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
      --member=user:$(gcloud config get-value account) \
      --role="roles/iam.serviceAccountTokenCreator" \
      --project=${PROJECT_ID}
    ```

1. **サービスアカウントにGCSバケットの管理の権限を付与**

   サービスカウントが、作成したバケットの操作することを許可する必要があります。

    ```bash
    # サービスアカウントにGCSバケットへのIAMロールを付与
    gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
      --member=serviceAccount:${SA_EMAIL} \
      --role="roles/storage.objectAdmin"
    ```

-----

### ステップ5: Terraformファイルの作成と初期化

最後に、ローカルに作業ディレクトリを作成し、最初のTerraformファイル群を準備します。

1. **Global変数を定義**

    ```bash
    cat << EOF > ./terraform/common.tfvars
    terraform_service_account_email="${SA_EMAIL}"
    EOF

    cat ./terraform/common.tfvars
    ```

1. **作業ディレクトリを作成**

    ディレクトリ構成はREADME.mdを参照のこと

    ```bash
    cd ./terraform/0_bootstrap
    ```

1. **`versions.tf` を作成**
    TerraformとGoogle Providerのバージョンを定義します。

    ```hcl
    # versions.tf
    terraform {
        # "~>" を使い、意図しないメジャー/マイナーアップデートを防ぎます
        required_version = "~> 1.12.2"

      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "~> 6.48.0"
        }
      }
    }
    ```

1. **`backend.tf` を作成**
    `.tfstate`の保存場所として、先ほど作成したGCSバケットを指定します。

    ```hcl
    # backend.tf
    terraform {
      backend "gcs" {
        prefix = "bootstrap"
      }
    }
    ```

1. **`provider.tf` を作成**

    ```hcl
    # provider.tf
    provider "google" {
      // この設定により、Terraform実行時に自動でSAを借用します
      impersonate_service_account = var.terraform_service_account_email
    }
    ```

1. **`variables.tf` を作成** # variables.tf
    provider.tfのimpersonate_service_accountに値を渡すための変数を定義します。

    ```hcl
    # variables.tf
    variable "terraform_service_account_email" {
      type        = string
      description = "TerraformがGCPを操作するために借用するサービスアカウントのメールアドレスです。"
    }
    ```

1. **`.gitignore` を作成**
    Terraformが生成する不要なファイルをGitの管理対象から除外します。

    ```git
    # .gitignore
    .terraform/
    .terraform.lock.hcl
    .terraform-version
    *.tfstate
    *.tfstate.*
    *.tfvars
    *.tfbackend
    *.common.tfbackend
    domain.env
    ```

1. **Terraformを初期化**
    すべてのファイルを保存したら、最後に`terraform init`を実行します。

    ```bash
    # 自動参照する環境変数を定義
    export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=$SA_EMAIL

    # 認証を初期化
    gcloud auth application-default revoke
    gcloud auth application-default login
    gcloud auth application-default set-quota-project $PROJECT_ID

    terraform init -backend-config="../common.tfbackend"

    # -reconfigureオプションは、設定変更時に役立ちます
    terraform init \
      -reconfigure \
      -backend-config="../common.tfbackend"
    ```

    "Terraform has been successfully initialized\!" と表示されれば、バックエンドの設定は成功です。

お疲れ様でした！これで、Terraformを使って安全にGCP組織リソースを管理していくためのすべての準備が整いました。このディレクトリで`.tf`ファイルを追加していくことで、フォルダやプロジェクトの作成を自動化できます。
