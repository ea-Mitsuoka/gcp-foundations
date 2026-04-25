# 新しいプロジェクトを追加する手順 (自動化フロー)

本リポジトリでは、新しいプロジェクトの追加はすべて自動化されています。
手動でのディレクトリ作成やTerraformコードの記述を最小限に抑え、SSOT（信頼できる唯一の情報源）であるスプレッドシートに基づいて構成を管理します。

## 1. スプレッドシートの更新

リポジトリルートにある `gcp_foundations.xlsx` を開き、新しく作成したいプロジェクトの情報を追記します。

- **必須項目**: 組織名、アプリ名、環境、親フォルダIDなど。
- **注意点**: 初回作成時は、API有効化を確実に行うため、まずプロジェクトの「器」を作る必要があります。
- **詳細**: 記載方法の詳細は `docs/reference/spreadsheet_format.md` を参照してください。

## 2. リソースファイルの自動生成

`deploy_all.sh` を実行する前に、手動でリソース生成スクリプトを実行し、意図した通りにTerraformコードや `tfvars` が生成されるか確認します。

```bash
uv run terraform/scripts/generate_resources.py
```

実行後、`terraform/4_projects/` 配下に新しいプロジェクトのディレクトリ（例: `prd-app-01`）が作成され、その中の `terraform.tfvars` などに正しい値が設定されていることを確認してください。

## 3. 実行計画 (Plan) の確認

生成されたコードに問題がないか、対象プロジェクトのディレクトリに移動して `terraform plan` を実行します。

```bash
cd terraform/4_projects/<新しいプロジェクト名>
terraform init -backend-config="$(git rev-parse --show-toplevel)/terraform/common.tfbackend"
terraform plan -var-file="$(git rev-parse --show-toplevel)/terraform/common.tfvars"
```

※ エラーがないこと、意図したリソースが作成されることを確認してください。

## 4. デプロイの実行

Planの結果に問題がなければ、リポジトリルートに戻り、一括デプロイスクリプトを実行して実際の環境に適用します。

```bash
make deploy
```

このコマンドにより、バックエンド設定の初期化、変数の注入、および全レイヤーの順次デプロイが自動的に行われます。
