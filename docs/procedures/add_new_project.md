# 新しいプロジェクトを追加する手順

このドキュメントは、このリポジトリのProject Factoryパターンに従って、新しいアプリケーションやサービスのためのGCPプロジェクト群を追加する際の手順を説明します。

## 前提

- `terraform/4_projects/`ディレクトリ配下で、新しいプロジェクトを管理します。
- 既存の`terraform/4_projects/example_project`をテンプレートとして利用します。

## 手順

ここでは、例として`my-new-app`という新しいアプリケーションのプロジェクトを追加する場合を想定します。

### 1. 既存プロジェクトのディレクトリをコピー

まず、`example_project`ディレクトリを、新しいプロジェクト名でコピーします。

```bash
cp -r terraform/4_projects/example_project terraform/4_projects/my-new-app
```

### 2. `backend.tf`の修正

コピーしたディレクトリ内の`backend.tf`を修正し、TerraformのStateを管理するGCSのパス（prefix）が他のプロジェクトと重複しないようにします。

**ファイル:** `terraform/4_projects/my-new-app/backend.tf`

```terraform
terraform {
  backend "gcs" {
    # bucketは共通のものを参照するため、修正不要
    prefix = "projects/my-new-app" # "projects/example_project" から変更
  }
}
```

### 3. `variables.tf`の値を調整（任意）

必要に応じて、`terraform/4_projects/my-new-app/variables.tf`内のデフォルト値を調整します。特に、有効化したいAPIのリスト`project_apis`や、プロジェクトに付与する`labels`などは、新しいプロジェクトの要件に合わせて変更することが多いでしょう。

```terraform
# terraform/4_projects/my-new-app/variables.tf の例

variable "project_apis" {
  description = "A set of APIs to enable on the project."
  type        = set(string)
  default = [
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    # ... 新しいプロジェクトで必要なAPIを追加・削除
  ]
}
```

### 4. CIワークフローへの反映

このリポジトリに導入されているCIワークフロー（`.github/workflows/lint.yml`）は、**ディレクトリを自動的に検出**します。
そのため、新しいプロジェクトディレクトリを追加した際に、**CIの定義ファイル（`.yml`）を修正する必要は一切ありません。**

新しいディレクトリ内の`.tf`ファイルは、自動的に`validate`ジョブの対象となります。

### 5. コミット & プルリクエスト

変更したファイルと新しく追加したディレクトリをコミットし、GitHubでプルリクエストを作成します。

```bash
git add terraform/4_projects/my-new-app/
git commit -m "feat: add new project for my-new-app"
git push origin <your-branch-name>
```

プルリクエストを作成すると、自動的にCIが実行され、`terraform fmt`, `tflint`, `terraform validate`などのチェックが行われます。すべてのチェックが成功することを確認してください。

### 6. `terraform apply` の実行

プルリクエストがレビューされ、`main`ブランチにマージされた後、ローカル環境から`terraform apply`を実行して、実際にGCP上にリソースを作成します。

> **Note:**
> 現在、`apply`を自動実行するCD（継続的デプロイ）は導入されていません。将来的には、`main`ブランチへのマージをトリガーに`apply`を自動実行する仕組みの導入が推奨されます。

```bash
# 新しいプロジェクトのディレクトリに移動
cd terraform/4_projects/my-new-app

# (初回のみ) Terraformの初期化
terraform init

# 実行計画の確認
terraform plan

# 計画に問題がなければ、リソースを適用
terraform apply
```

以上で、新しいプロジェクトの追加は完了です。
