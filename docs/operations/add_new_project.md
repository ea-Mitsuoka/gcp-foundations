# 新しいプロジェクトを追加する手順

本リポジトリでは、新しいプロジェクトの追加はすべて自動化されています。
手作業でディレクトリをコピーしたり、Terraformファイルを手書きで修正する必要はありません。

## 手順

1. **スプレッドシートの更新**
   リポジトリルートにある `projects_config.xlsx` を開き、新しく作成したいプロジェクトの情報を新しい行に追記して保存します。
   ※ 記載方法の詳細は `docs/reference/spreadsheet_format.md` を参照してください。

1. **デプロイスクリプトの実行**
   ターミナルから以下の一括デプロイスクリプトを実行します。

   ```bash
   bash terraform/scripts/deploy_all.sh
   ```

スクリプトが自動的に `projects_config.xlsx` を読み取り、必要なTerraformディレクトリの生成、バックエンド設定の置換、変数の注入、およびデプロイまでを全自動で行います。

#### 3. `docs/operations/create_project.md` (「3. Terraformで作成する方法」以降を上書き)

※前半の `1. コンソールで作成する方法` と `2. gcloudコマンドで作成する方法` は残し、後半のTerraformの手順を以下で上書きしてください。

````markdown
## 3. Terraformで作成する方法（推奨）

リポジトリ (`gcp-foundations`) を使い、**Infrastructure as Code (IaC) として**プロジェクトを管理します。本リポジトリではSSOTの原則に従い、個別のtfvarsの手書きや手動でのterraformコマンドの実行は行いません。

### **ステップ1：プロジェクト情報の登録**

ルートディレクトリにある `projects_config.xlsx` を開き、新しく作成したいプロジェクトの要件を行として追加します。
初回作成時は、必ず `billing_linked` カラムを `FALSE` としてください。

### **ステップ2：デプロイの実行（第1段階：プロジェクトの作成）**

スクリプトを実行し、プロジェクトの「器」だけを作成します。

```bash
bash terraform/scripts/deploy_all.sh
````

### ステップ3：課金アカウントのリンク（手動）

GCPコンソール画面、または以下のコマンドを使用して、作成されたプロジェクトに課金アカウントをリンクしてください。

```bash
gcloud billing projects link <作成されたプロジェクトID> --billing-account=<あなたの請求先アカウントID>
```

### ステップ4：APIの有効化（第2段階）

projects_config.xlsx の対象プロジェクトの billing_linked を TRUE に変更し、再度デプロイを実行してAPIの有効化など残りの設定を適用します。

```bash
bash terraform/scripts/deploy_all.sh
```
