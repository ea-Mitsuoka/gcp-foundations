# フォルダ作成の手順

組織内のプロジェクトを構造化して管理するための「フォルダ」を作成する方法を説明します。

---

## 1. Google Cloud コンソールで作成する方法

GUI を使った、最も簡単な作成方法です。

1. **[リソースの管理](https://console.cloud.google.com/cloud-resource-manager)ページ**へ移動します。
1. 画面上部の **[フォルダを作成]** をクリックします。
1. **フォルダ名**（例: `Production`）を入力し、場所（組織または親フォルダ）を選択します。
1. **[作成]** をクリックします。

---

## 2. gcloud コマンドで作成する方法

### 組織直下に作成する場合
```bash
gcloud resource-manager folders create \
  --display-name="Production" \
  --organization="YOUR_ORGANIZATION_ID"
```

### 既存のフォルダ配下に作成する場合
```bash
gcloud resource-manager folders create \
  --display-name="App-Team-A" \
  --folder="PARENT_FOLDER_ID"
```

---

## 3. Terraform で作成する方法 (推奨)

本基盤の IaC 管理に統合するために、`terraform/3_folders` レイヤーで管理することを推奨します。

### ステップ 1: `main.tf` への追記
`terraform/3_folders/main.tf` を開き、`google_folder` リソースを定義します。

```hcl
resource "google_folder" "new_folder" {
  display_name = "New-Folder-Name"
  parent       = "organizations/${var.organization_id}" # または "folders/${var.parent_folder_id}"
}
```

### ステップ 2: デプロイの実行
リポジトリルートで `make deploy` を実行するか、個別に適用します。

```bash
cd terraform/3_folders
terraform init -backend-config="../common.tfbackend"
terraform plan -var-file="../common.tfvars"
terraform apply -var-file="../common.tfvars"
```

> **ポイント**: Terraform で管理することで、フォルダ構成の変更履歴を Git で追跡できるようになり、誤削除の防止や再現性の確保に繋がります。
