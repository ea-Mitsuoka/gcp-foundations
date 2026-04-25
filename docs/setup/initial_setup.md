# 初期環境セットアップガイド (Initial Setup Guide)

本ドキュメントでは、本リポジトリを使用して**新しいGCP組織に対してインフラ基盤（GCP Foundations）をゼロから構築する手順**を解説します。

## 概要 (Overview)

この基盤の構築は、Terraformの状態（State）を管理する「管理用プロジェクト」の作成から始まり、組織全体のポリシー、ログ集約、監視、ネットワークへと段階的に展開されます。

### セットアップの全体フロー
1. **事前準備**: ツールインストール、Google Groups作成、GCP認証。
2. **シード実行**: `setup_new_client.sh` による管理リソースの自動作成。
3. **課金リンク (手動)**: 管理用プロジェクトへの課金アカウント紐付け。
4. **Layer 0 デプロイ**: BootstrapリソースのTerraform管理化。
5. **コア基盤デプロイ**: ログ・監視・ネットワークの一括展開（2段階）。

---

## 1. 事前準備 (Prerequisites)

作業を開始する前に、以下の準備を完了させてください。

### 1.1. 必要ツールのインストール
以下のツールが作業環境にインストールされていることを確認してください。
- `gcloud` CLI
- `terraform` (v1.6.0以上)
- `uv` (Pythonパッケージマネージャ)
- `openssl`, `git`, `make`

### 1.2. Google Groups の作成 (必須)
組織レベルの権限（IAM）をグループベースで管理するため、Google Workspace または Cloud Identity 上で以下のグループを事前に作成してください。
- `gcp-organization-admins@<domain>`
- `gcp-billing-admins@<domain>`
- `gcp-vpc-network-admins@<domain>`
- `gcp-security-admins@<domain>`
- `gcp-logging-monitoring-admins@<domain>`
- `gcp-devops@<domain>`

### 1.3. GCPへの認証
組織管理者権限を持つアカウントでログインしてください。
```bash
gcloud auth login
gcloud auth application-default login
```

---

## 2. 自動セットアップスクリプトの実行

管理用プロジェクトと tfstate 保存用バケットを自動作成します。

```bash
# スクリプトの実行
bash terraform/scripts/setup_new_client.sh
```

### 入力項目
- **Customer's domain**: 管理対象のドメイン (例: `example.com`)
- **GCP region**: バケットを作成するリージョン (例: `asia-northeast1`)
- **Shared VPC / VPC-SC**: 必要に応じて `true`/`false` を選択（デフォルト `false`）

---

## 3. 【手動操作】管理用プロジェクトの課金リンク

スクリプトの実行中に以下のメッセージが表示され、一時停止します。

```text
-------------------- MANUAL ACTION REQUIRED --------------------
GCP requires an active billing account to enable APIs and create GCS buckets.
...
  gcloud billing projects link <MGMT_PROJECT_ID> --billing-account=<BILLING_ID>
----------------------------------------------------------------
```

指示に従い、**別のターミナルを開いて**課金アカウントをリンクしてください。完了後、元のターミナルに戻り `Enter` を押すと処理が続行されます。

---

## 4. Layer 0 (Bootstrap) の適用

スクリプト完了後、管理リソースを Terraform の管理下に置きます。

```bash
cd terraform/0_bootstrap

# 初期化 (自動生成された backend 構成を使用)
terraform init -backend-config="../common.tfbackend"

# デプロイ
terraform apply -var-file="../common.tfvars" -var-file="terraform.tfvars"

# APIの有効化
cd google_project_service
terraform init -backend-config="../../common.tfbackend"
terraform apply -var-file="../../common.tfvars" -var-file="terraform.tfvars"

# IAM権限の適用
cd ../iam
terraform init -backend-config="../../common.tfbackend"
terraform apply -var-file="../../common.tfvars" -var-file="terraform.tfvars"
```

---

## 5. 基盤全体の一括デプロイ (2段階)

最後に、ログ集約やネットワーク等の全レイヤーをデプロイします。**課金アカウントのリンクを挟むため、2段階で実行します。**

### 5.1. 第1段階: 「器」の作成
まず、リポジトリルートの `gcp_foundations.xlsx` を最新化し、デプロイを実行します。
（※ `core_billing_linked = false` のため、API有効化はスキップされます）

```bash
make deploy
```

### 5.2. 【手動操作】コアプロジェクトの課金リンク
作成された以下のプロジェクトに対し、手動で課金アカウントをリンクしてください。
- ログ集約プロジェクト (`[prefix]-logsink`)
- 監視プロジェクト (`[prefix]-monitoring`)
- （有効な場合）Shared VPC ホストプロジェクト

### 5.3. 第2段階: サービスの実装
`terraform/common.tfvars` のフラグを `true` に書き換えます。

```hcl
core_billing_linked = true
```

再度デプロイを実行します。スキップされていた API 有効化やログシンクの設定が適用されます。

```bash
make deploy
```

🎉 **"All deployments completed successfully!"** と表示されれば、初期環境の構築はすべて完了です。
