# フォルダ作成方法

-----

## 1. コンソールで作成する方法

GUI（グラフィカル・ユーザー・インターフェース）を使って手動で作成する、最も直感的な方法です。

1. **リソースの管理画面に移動**

      * Google Cloudコンソールにログインし、画面左上のナビゲーションメニューから **[IAMと管理] \> [リソースの管理]** を選択します。
      * または、直接 [こちらのリンク](https://console.cloud.google.com/cloud-resource-manager) にアクセスします。

2. **フォルダの作成を開始**

      * 画面上部にある **[フォルダを作成]** をクリックします。

3. **詳細を入力**

      * **フォルダ名**: 分かりやすい名前を入力します（例: `Production`）。
      * **組織**: あなたの組織名が選択されていることを確認します。
      * **場所**: 「組織」を選択します。これにより、フォルダは組織の直下に作成されます。

4. **作成**

      * **[作成]** ボタンをクリックします。

> **ポイント**: この方法は手軽ですが、手作業のため再現性がなく、IaC（Infrastructure as Code）の原則からは外れます。構成のテストや確認には便利です。

-----

## 2. コマンドで作成する方法

`gcloud` CLI（コマンドラインインターフェース）を使って作成する方法です。スクリプト化しやすく、コンソール操作よりも高速です。

1. **コマンドを実行**

      * ターミナルを開き、以下のコマンドを実行します。`--display-name` には作成したいフォルダ名を入れてください。

    <!-- end list -->

    ```bash
    # 以前のステップで設定した環境変数が有効なことを確認
    echo ${ORGANIZATION_ID}

    # まずフォルダ作成者の権限を付与する
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
    --member="user:$(gcloud config get-value account)" \
    --role="roles/resourcemanager.folderCreator"

    # "Production" という名前のフォルダを作成する例
    gcloud resource-manager folders create \
      --display-name="Production" \
      --organization=${ORGANIZATION_ID}
    ```

2. **実行結果の確認**

      * コマンドが成功すると、作成されたフォルダの名前とID（`folders/12345...`）が出力されます。このフォルダIDは、Terraformなどでリソースを管理する際に利用できます。

> **ポイント1**: この方法は自動化しやすいですが、インフラの状態（State）を管理する仕組みがないため、Terraformのように「現在のインフラがどうあるべきか」をコードで管理することはできません。</br> **ポイント2**: 実際の運用では、組織管理者は少数の信頼できる者に限定して組織管理者と別の担当者に分けるのがベストプラクティスです。</br> **ポイント3**: コンソールで操作をすると組織管理者が実行すればエラーになりませんが、gcloudコマンドだとフォルダ作成者の権限を付与せずにフォルダ作成をすると権限エラーとなることがあります。必要に応じてフォルダ作成者の権限を付与してください。

-----

## 3. Terraformコードで作成する方法

これまで準備してきた環境を使い、**Infrastructure as Codeとしてフォルダを管理する、最も推奨される方法**です。</br>注意点としてCloud Identityの無償版を利用しているとアクセス制御の詳細な設定ができずにデフォルトの制御がかかってしまい、サービスアカウントの借用が失敗する場合がある。別のドキュメントを確認して、Cloud Shellからリポジトリをgit cloneした後で、Cloud Shell上で次の手順を進める

作業は`0_bootstrap`ディレクトリではなく、**`2_folders`ディレクトリ**で行います。

### **ステップ1: `2_folders`ディレクトリへ移動**

```bash
# gcp-foundationsのルートディレクトリにいると仮定
cd terraform/2_folders
```

### **ステップ2: `backend.tf` を設定**

`0_bootstrap`で作成したGCSバケットを指定し、`prefix`を変更してtfstateが分離されるようにします。

```hcl
# terraform/2_folders/backend.tf

terraform {
  backend "gcs" {
    # このディレクトリ用のtfstateの保存場所を区別するためのprefix
    prefix = "folders"
  }
}
```

### **ステップ3: `main.tf` にリソースを定義**

`google_folder`リソースを使って、作成したいフォルダを定義します。

```hcl
# terraform/2_folders/main.tf

# "Production"フォルダ
resource "google_folder" "production" {
  display_name = "Production"
  parent       = "organizations/${var.organization_id}"
}

# "Development"フォルダ
resource "google_folder" "development" {
  display_name = "Development"
  parent       = "organizations/${var.organization_id}"
}
```

### **ステップ4: `variables.tf` を作成**

`main.tf`で使っている変数を定義します。

```hcl
# terraform/2_folders/variables.tf

variable "organization_id" {
  type        = string
  description = "フォルダを作成する親となるGCP組織ID。"
}
```

### **ステップ5: 環境変数でTerraformに変数を渡す**

`terraform.tfvars`ファイルは作成しません。代わりに、ターミナルで以下のコマンドを実行し、Terraformが自動で読み込む環境変数を設定します。

```bash
# 以前のステップで設定したORGANIZATION_IDの環境変数を
# Terraformが読み取れる形式の環境変数に設定します。
export TF_VAR_organization_id=${ORGANIZATION_ID}

# 設定されたか確認
echo $TF_VAR_organization_id
```

### **ステップ6: Terraformを実行**

1. **初期化**: 新しいディレクトリで作業を始めたので、再度`init`が必要です。

    ```bash
    terraform init -backend-config="bucket=${BUCKET_NAME}"

    # -reconfigureオプションは、設定変更時に役立ちます
    terraform init \
      -reconfigure \
      -backend-config="bucket=${BUCKET_NAME}"
    ```

2. **適用**: `plan`で内容を確認し、問題なければ`apply`を実行します。

    ```bash
    terraform plan
    terraform apply
    ```

> **ポイント1**: この方法で作成・管理することで、「インフラがコードで定義されている」状態になります。Gitで変更履歴を管理でき、誰がいつ何を変更したかが明確になり、インフラの再現性と信頼性が飛躍的に向上します。
