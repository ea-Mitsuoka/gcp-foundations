# プロジェクト作成方法 (手動・リファレンス)

本基盤では `project_addition.md` に記載の自動化フローを推奨しますが、緊急時やデバッグのために手動でプロジェクトを作成・管理する場合の手順を以下に示します。

---

## 1. Google Cloud コンソールで作成する方法

GUI を使い、手動でプロジェクトを作成する最も直感的な方法です。

1. **[リソースの管理](https://console.cloud.google.com/cloud-resource-manager)ページ**を開きます。
1. **[プロジェクトを作成]** をクリックします。
1. **詳細を入力**:
   - **プロジェクト名**: 識別しやすい名前 (例: `My App (Dev)`)。
   - **請求先アカウント**: 組織の請求先アカウント。
   - **場所**: 作成済みのフォルダ（例: `Development`）を親として選択します。
1. **[作成]** をクリックします。

---

## 2. gcloud コマンドで作成する方法

CLI を使い、スクリプト等でプロジェクトを作成する場合に便利です。

### ステップ 1: 環境変数の設定
```bash
export FOLDER_ID="YOUR_FOLDER_ID"
export PROJECT_ID="org-dev-app-01" # グローバルで一意である必要があります
```

### ステップ 2: プロジェクトの作成
```bash
gcloud projects create ${PROJECT_ID} \
  --folder="${FOLDER_ID}" \
  --name="App Dev 01"
```

### ステップ 3: 課金の有効化
```bash
export BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1)

gcloud billing projects link ${PROJECT_ID} \
  --billing-account=${BILLING_ACCOUNT_ID}
```

---

## 3. Terraform で直接作成する方法 (低レイヤー操作)

自動生成スクリプト (`generate_resources.py`) を介さず、直接 Terraform ディレクトリを操作する場合の手順です。

### ステップ 1: プロジェクトディレクトリの準備
`terraform/4_projects/` 配下に新しいディレクトリを作成し、`main.tf`, `variables.tf`, `versions.tf` を用意します。既存のプロジェクトディレクトリをコピーするのが効率的です。

### ステップ 2: Terraform の初期化と実行
```bash
cd terraform/4_projects/<target_dir>

# 共通バックエンド設定を使用して初期化
terraform init -backend-config="../../common.tfbackend"

# 実行計画の確認と適用
terraform plan -var-file="../../common.tfvars"
terraform apply -var-file="../../common.tfvars"
```

> **注意**: 手動で作成したリソースを後からスプレッドシート管理（SSOT）に組み込む場合は、`terraform import` コマンドを使用して状態を同期させる必要があります。
