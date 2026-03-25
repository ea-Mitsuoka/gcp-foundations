# 特定の環境をセットアップする手順

このドキュメントは、単一のTerraformコードから開発(dev)・ステージング(stag)・本番(prod)といった複数の環境をセットアップし、管理するための手順を説明します。

ここでは、Terraformの`workspace`機能と`.tfvars`ファイルを利用して、環境ごとの状態と設定値を分離するベストプラクティスに従います。

## 前提

- `0_bootstrap`から`3_folders`までの共通基盤が適用済みであること。
- 適用対象のプロジェクトのコード（例: `terraform/4_projects/my-new-app`）が作成済みであること。

## 手順

ここでは`terraform/4_projects/my-new-app`プロジェクトに、新しく`dev`環境をセットアップする場合を想定します。

### 1. 環境ごとの設定ファイル (`.tfvars`) を作成

環境によって値を変えたい変数（例: `project_id`の接尾辞、マシンタイプ、有効化するAPIなど）を定義するためのファイルを作成します。

`terraform/4_projects/my-new-app/`ディレクトリ内に、`dev.tfvars`という名前でファイルを作成します。

**ファイル:** `terraform/4_projects/my-new-app/dev.tfvars`

```hcl
# dev.tfvars の例

# プロジェクトIDや命名に使われる接尾辞
environment = "dev"

# dev環境で有効化するAPI
project_apis = [
  "compute.googleapis.com",
  "storage.googleapis.com",
  "iam.googleapis.com",
  "monitoring.googleapis.com",
  "logging.googleapis.com"
]

# dev環境用のラベル
labels = {
  env         = "development"
  app         = "my-new-app"
  team        = "awesome-team"
  cost-center = "12345-dev"
}
```

同様に、`stag.tfvars`や`prod.tfvars`も作成することで、環境ごとの設定を管理できます。

### 2. Terraform Workspace の作成

`workspace`を使うと、同じコードでも環境ごとに`tfstate`ファイルが分離され、`dev`環境の変更が誤って`prod`環境に影響を与える、といった事故を防ぐことができます。

1. **対象のディレクトリに移動します。**

    ```bash
    cd terraform/4_projects/my-new-app
    ```

2. **`dev`ワークスペースを新規に作成します。**
    （初回のみ）

    ```bash
    terraform workspace new dev
    ```

    これで`dev`という名前のワークスペースが作成され、自動的にそのワークスペースに切り替わります。

    既存のワークスペースの一覧は`terraform workspace list`で、現在のワークスペースは`terraform workspace show`で確認できます。

### 3. `terraform apply` の実行

特定の環境に対応するワークスペースと`.tfvars`ファイルを指定して、`apply`を実行します。

1. **対象のワークスペースに切り替えます。**
    （すでに`dev`にいる場合は不要）

    ```bash
    terraform workspace select dev
    ```

2. **`init`と`plan`を実行します。**

    ```bash
    terraform init
    terraform plan -var-file="dev.tfvars"
    ```

    `-var-file`フラグで、手順1で作成した環境ごとの設定ファイルを指定します。

3. **`apply`を実行します。**
    `plan`の内容に問題がなければ、`apply`を実行します。

    ```bash
    terraform apply -var-file="dev.tfvars"
    ```

### 他の環境をセットアップする場合

同様に、`prod`環境をセットアップする場合は、以下のようになります。

1. `prod.tfvars`ファイルを作成します。
2. `terraform workspace new prod`で`prod`ワークスペースを作成します。
3. `terraform workspace select prod`で`prod`に切り替えます。
4. `terraform apply -var-file="prod.tfvars"`を実行します。

この手順により、安全かつ再現性の高い方法で、複数の環境を管理することができます。
