# フォルダ作成の手順

本基盤では、組織内の階層構造（Prod/Dev 等）を管理するために「フォルダ」を使用します。
IaC による管理を徹底するため、Terraform による作成を推奨します。

---

## 1. 推奨手順: Terraform による管理

フォルダの追加・変更は `terraform/3_folders` レイヤーで行います。

### ステップ 1: `main.tf` の編集
`terraform/3_folders/main.tf` に、新しいフォルダのリソースを定義します。

```hcl
resource "google_folder" "new_department" {
  display_name = "Department-X"
  parent       = "organizations/${var.organization_id}"
}
```

### ステップ 2: 適用 (Apply)
リポジトリルートでデプロイを実行します。
```bash
make deploy
```
個別に適用する場合は以下を実行します。
```bash
cd terraform/3_folders
terraform init -backend-config="../common.tfbackend"
terraform apply -var-file="../common.tfvars"
```

---

## 2. 参考: 手動・コマンドによる作成

検証目的などで一時的に作成する場合の手順です。

- **Google Cloud コンソール**: [リソースの管理](https://console.cloud.google.com/cloud-resource-manager)ページから「フォルダを作成」をクリック。
- **gcloud コマンド**:
  ```bash
  gcloud resource-manager folders create --display-name="Temp-Folder" --organization="YOUR_ORG_ID"
  ```

> **注意**: 手動で作成したフォルダを後から Terraform 管理に含めるには、`terraform import` コマンドを使用して状態を同期させる必要があります。
