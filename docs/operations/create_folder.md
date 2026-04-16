# フォルダ作成方法

______________________________________________________________________

## 1. コンソールで作成する方法

GUI（グラフィカル・ユーザー・インターフェース）を使って手動で作成する、最も直感的な方法です。

1. **リソースの管理画面に移動**

   - Google Cloudコンソールにログインし、画面左上のナビゲーションメニューから **[IAMと管理] > [リソースの管理]** を選択します。
   - または、直接 [こちらのリンク](https://console.cloud.google.com/cloud-resource-manager) にアクセスします。

1. **フォルダの作成を開始**

   - 画面上部にある **[フォルダを作成]** をクリックします。

1. **詳細を入力**

   - **フォルダ名**: 分かりやすい名前を入力します（例: `Production`）。
   - **組織**: あなたの組織名が選択されていることを確認します。
   - **場所**: 「組織」を選択します。これにより、フォルダは組織の直下に作成されます。

1. **作成**

   - **[作成]** ボタンをクリックします。

> **ポイント**: この方法は手軽ですが、手作業のため再現性がなく、IaC（Infrastructure as Code）の原則からは外れます。構成のテストや確認には便利です。

______________________________________________________________________

## 2. コマンドで作成する方法

`gcloud` CLI（コマンドラインインターフェース）を使って作成する方法です。スクリプト化しやすく、コンソール操作よりも高速です。

1. **コマンドを実行**

   - ターミナルを開き、以下のコマンドを実行します。`--display-name` には作成したいフォルダ名を入れてください。

   <!-- end list -->

   ```bash
   # 以前のステップで設定した環境変数が有効なことを確認
   echo ${ORGANIZATION_ID}
   echo ${SA_EMAIL}

   # "Production" という名前のフォルダを作成する例
   gcloud resource-manager folders create \
     --display-name="Production" \
     --organization=${ORGANIZATION_ID} \
     --impersonate-service-account=${SA_EMAIL}
   ```

1. **実行結果の確認**

   - コマンドが成功すると、作成されたフォルダの名前とID（`folders/12345...`）が出力されます。このフォルダIDは、Terraformなどでリソースを管理する際に利用できます。

> **ポイント**: この方法は自動化しやすいですが、インフラの状態（State）を管理する仕組みがないため、Terraformのように「現在のインフラがどうあるべきか」をコードで管理することはできません。

______________________________________________________________________

## 3. Terraformコードで作成する方法

これまで準備してきた環境を使い、**Infrastructure as Codeとしてフォルダを管理する、最も推奨される方法**です。</br>注意点としてCloud Identityの無償版を利用しているとアクセス制御の詳細な設定ができずにデフォルトの制御がかかってしまい、サービスアカウントの借用が失敗する場合がある。別のドキュメントを確認して、Cloud Shellからリポジトリをgit cloneした後で、Cloud Shell上で次の手順を進める

作業は`0_bootstrap`ディレクトリではなく、**`2_folders`ディレクトリ**で行います。

### **ステップ1: `2_folders`ディレクトリへ移動**

```bash
# gcp-foundationsのルートディレクトリにいると仮定
cd terraform/2_folders
```

#### **`main.tf`**

`google_folder`リソースを使って、作成したいフォルダを定義します。

```hcl
# terraform/2_folders/main.tf
data "google_organization" "org" {
  domain = var.organization_domain
}

# "Production"フォルダ
resource "google_folder" "production" {
  display_name = "Production"
  parent       = data.google_organization.org.name
}

# "Development"フォルダ
resource "google_folder" "development" {
  display_name = "Development"
  parent       = data.google_organization.org.name
}
```

### ステップ2: Terraformを実行

<!-- 1. **Cloud Shellにログイン**: サービスアカウントの借用を設定をする

   ```bash
   cd ~/gcp-foundations/terraform/2_folders
   gcloud auth application-default login --impersonate-service-account=${SA_EMAIL}
   ``` -->

以下の標準コマンド群をコピー＆ペーストして実行してください。（`deploy_all.sh` を利用して一括デプロイすることも可能です）

```bash
# 1. スクリプトのパスを通す
export PATH="$(git rev-parse --show-toplevel)/terraform/scripts:$PATH"

# 2. backend用のバケット情報を取得・セット
set-gcs-bucket-value.sh .

# 3. 初期化
terraform init -backend-config="$(git-root)/terraform/common.tfbackend" -reconfigure

# 4. 実行計画の確認
terraform plan -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"

# 5. リソースの適用
terraform apply -var-file="$(git-root)/terraform/common.tfvars" -var-file="terraform.tfvars"
```

> **ポイント**: この方法で作成・管理することで、「インフラがコードで定義されている」状態になります。Gitで変更履歴を管理でき、誰がいつ何を変更したかが明確になり、インフラの再現性と信頼性が飛躍的に向上します。
