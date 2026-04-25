# 初期環境セットアップ手順

本ドキュメントでは、新しい GCP 組織に対して「GCP Foundations」基盤をゼロから構築する手順を説明します。

---

## 1. 事前準備 (Prerequisites)

### 1.1. ツールのインストール
作業環境に必要なツール（`gcloud`, `terraform`, `uv` 等）のインストールについては、以下のドキュメントを参照して完了させてください。
- **[ローカル開発環境セットアップガイド](../development/local_development.md)**

### 1.2. 管理グループの作成 (Google Groups)
IAM 統制のため、以下のグループを事前に作成しておく必要があります。
- `gcp-organization-admins@<your-domain>`
- `gcp-security-admins@<your-domain>`
- `gcp-network-admins@<your-domain>`
- `gcp-billing-admins@<your-domain>`

### 1.3. GCP 認証
組織管理者権限を持つアカウントでログインします。
```bash
gcloud auth login
gcloud auth application-default login
```

---

## 2. 基盤の構築ステップ

### ステップ 1: シードリソースの作成 (管理プロジェクトとバケット)
```bash
bash terraform/scripts/setup_new_client.sh
```
※ 途中で課金アカウントのリンクを求められるので、指示に従ってください。

### ステップ 2: Layer 0 (Bootstrap) の適用
```bash
cd terraform/0_bootstrap
terraform init -backend-config="../common.tfbackend"
terraform apply -var-file="../common.tfvars" -var-file="terraform.tfvars"
```

### ステップ 3: コア基盤の一括展開
リポジトリルートに戻り、全レイヤーをデプロイします。
```bash
make deploy
```

---

## 3. 次のステップ

構築完了後は、以下の手順でアプリケーション用プロジェクトを追加できます。
- **[プロジェクトのライフサイクル管理](../operations/project_lifecycle.md)**
