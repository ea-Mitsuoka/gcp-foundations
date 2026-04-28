# フォルダ作成の手順

本基盤では、組織内の階層構造（Prod/Dev 等）を管理するために「フォルダ」を使用します。
原則として、`gcp-foundations.xlsx` を用いた IaC による自動管理を行います。

______________________________________________________________________

## 1. 推奨手順: Excel による管理

フォルダの追加・変更はプロジェクトルートにある `gcp-foundations.xlsx` で定義します。

### ステップ 1: `gcp-foundations.xlsx` の編集

1. `gcp-foundations.xlsx` を開き、`resources` シートを選択します。
1. `resource_type` に `folder` を指定し、新しいフォルダを定義します。
   - `parent_name`: 親フォルダ名、または組織直下の場合は `organization_id` を指定します。
   - `resource_name`: フォルダの表示名（Terraform のリソース名にも使用されます）を指定します。

### ステップ 2: Terraform コードの生成

以下のコマンドを実行し、Excel の定義から Terraform ファイル（`auto_folders.tf`）を自動生成します。

```bash
make generate
```

> **注意**: `terraform/3_folders/auto_folders.tf` は自動生成されるファイルです。手動で編集しないでください。

### ステップ 3: 適用 (Apply)

リポジトリルートでデプロイを実行します。

```bash
make deploy
```

個別にフォルダレイヤーのみ適用する場合は以下を実行します。

```bash
cd terraform/3_folders
terraform init -backend-config="../common.tfbackend"
terraform apply -var-file="../common.tfvars"
```

______________________________________________________________________

## 2. 参考: 手動・コマンドによる作成

検証目的などで一時的に作成する場合の手順です。

- **Google Cloud コンソール**: [リソースの管理](https://console.cloud.google.com/cloud-resource-manager)ページから「フォルダを作成」をクリック。
- **gcloud コマンド**:
  ```bash
  gcloud resource-manager folders create --display-name="Temp-Folder" --organization="YOUR_ORG_ID"
  ```

> **注意**: 手動で作成したフォルダを後から Terraform 管理に含めるには、`terraform import` コマンドを使用して状態を同期させる必要があります。
