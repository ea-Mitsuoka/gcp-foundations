# 後任者・リカバリガイド (Recovery & Succession)

本ドキュメントでは、前任者からリポジトリを引き継いだ後任の開発者が、不足している設定ファイルを復元し、安全に運用を再開するための手順を説明します。

本プロジェクトではセキュリティと情報の整理のため、多くの環境依存ファイル（`*.tfvars`, `*.tfbackend`, `domain.env` 等）が Git の管理対象外（`.gitignore`）となっています。これらが手元にない状態からスタートする場合、以下の手順に従ってください。

______________________________________________________________________

## 1. 必須設定ファイルの復元

リポジトリ直下および `terraform/` 配下で不足しているファイルを特定し、再作成します。

### ステップ 1: `domain.env` の作成

プロジェクトルートに `domain.env` を作成し、管理対象のドメインを記述します。

```bash
domain="example.com"
```

### ステップ 2: `common.tfbackend` の作成

Terraform の状態（State）が保存されている GCS バケットを特定します。

1. GCP コンソールで `*-tfstate-xxxx-bucket` という名前のバケットを探します。
1. `terraform/common.tfbackend` を作成し、そのバケット名を記述します。
   ```hcl
   bucket = "example-com-tfstate-abcd-bucket"
   ```

### ステップ 3: `common.tfvars` の再構成

基盤全体で共有される変数を定義します。このファイルは `make setup` 時に自動生成されますが、紛失した場合は再作成が必要です。

各パラメータの最新の定義および詳細な設定内容については、以下のガイドの **「ステップ 2.5: 共通変数ファイル (common.tfvars) の確認と調整」** セクションを必ず参照してください。

- **[初期環境セットアップガイド - common.tfvars の詳細](../setup/initial_setup.md#%E3%82%B9%E3%83%86%E3%83%83%E3%83%97-25-%E5%85%B1%E9%80%9A%E5%A4%89%E6%95%B0%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB-commontfvars-%E3%81%AE%E7%A2%BA%E8%AA%8D%E3%81%A8%E8%AA%BF%E6%95%B4)**

### ステップ 4: `gcp-foundations.xlsx` の復元

もしスプレッドシートがリポジトリに含まれていない場合は、現在の GCP 組織内のフォルダ構造やプロジェクト一覧から手動で再構築する必要があります。これが復元できないと `make generate` が正しく動作しません。

______________________________________________________________________

## 2. プロジェクト別 `terraform.tfvars` の復元

`terraform/4_projects/` 配下の各ディレクトリには `terraform.tfvars` が必要ですが、これも Git 管理外です。

- **SSoT (Excel) がある場合**:
  `make generate` を実行することで、Excel の定義に基づき全てのプロジェクトの `terraform.tfvars` が一括生成されます。
- **SSoT もない場合**:
  各ディレクトリで `terraform state pull` を実行して現在の設定値を確認し、手動で `terraform.tfvars` を作成する必要があります。

______________________________________________________________________

## 3. 特殊な運用操作

### プロジェクトの削除

後任者がプロジェクトを削除する場合、特に注意が必要です。詳細は `docs/operations/project_lifecycle.md` を参照してください。
主な流れは以下の通りです：

1. `terraform.tfvars` に `deletion_protection = false` を追記して `apply`。
1. `terraform apply -destroy -target=module.project` でターゲット指定して削除。
1. **絶対に `terraform destroy`（全体削除）を実行しない。**

### 実行権限の獲得 (Impersonation)

Terraform を実行するには、管理用サービスアカウントを借用（Impersonation）する権限が必要です。

```bash
# 自分自身にトークン作成権限を付与
gcloud iam service-accounts add-iam-policy-binding <SA_EMAIL> \
  --member="user:<YOUR_EMAIL>" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="<MGMT_PROJECT_ID>"
```

______________________________________________________________________

## 4. 継承時のチェックリスト

- [ ] `gcloud auth application-default login` が完了しているか
- [ ] `common.tfbackend` が正しいバケットを指しているか
- [ ] `make generate` でエラーが出ないか
- [ ] `terraform plan` を実行した際、コードの変更がないのにリソースの削除・変更が発生しようとしていないか（State とコード/tfvars が一致しているか）
