# プロジェクトのライフサイクル管理 (作成・運用・管理)

本リポジトリでは、GCPプロジェクトを「信頼できる唯一の情報源 (SSoT)」であるスプレッドシートに基づいて管理します。
自動化されたフローを推奨しますが、特定の状況下で必要な手動操作についても本ドキュメントで解説します。

______________________________________________________________________

## 1. 推奨手順: 自動化フローによるプロジェクト追加

新しいプロジェクトの追加は、スプレッドシートへの追記と自動生成スクリプトによって完結します。

### ステップ 1: スプレッドシートの更新

リポジトリルートにある `gcp-foundations.xlsx` を開き、作成したいプロジェクトの情報を追記します。

- **プロジェクトの定義**: 名称、親フォルダ、ネットワーク、セキュリティ境界を指定します。

### ステップ 2: リソースファイルの自動生成

以下のコマンドを実行し、Terraform コードと `tfvars` を生成します。

```bash
make generate
```

実行後、`terraform/4_projects/` 配下に新しいプロジェクトディレクトリが作成されていることを確認してください。

### ステップ 3: 実行計画 (Plan) の確認

対象ディレクトリに移動し、構成に問題がないか確認します。

```bash
cd terraform/4_projects/<新しいプロジェクト名>
terraform init -backend-config="../../common.tfbackend"
terraform plan -var-file="../../common.tfvars"
```

### ステップ 4: デプロイの実行

リポジトリルートに戻り、一括デプロイを実行します。

```bash
make deploy
```

______________________________________________________________________

## 2. 手動・リファレンス手順 (緊急時・デバッグ用)

自動化フローが利用できない場合や、特定のトラブルシューティングが必要な場合の手順です。

### A. gcloud コマンドによる作成

```bash
export PROJECT_ID="org-dev-app-01"
export FOLDER_ID="YOUR_FOLDER_ID"

# プロジェクト作成
gcloud projects create ${PROJECT_ID} --folder="${FOLDER_ID}"

# 課金のリンク
export BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1)
gcloud billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACCOUNT_ID}
```

### B. Google Cloud コンソールによる作成

1. [リソースの管理](https://console.cloud.google.com/cloud-resource-manager)ページへ。
1. **[プロジェクトを作成]** をクリックし、名称・フォルダ・請求先を選択。

> **重要**: 緊急時に手動でプロジェクトを作成した場合でも、必ず後で `gcp-foundations.xlsx` にその情報を追記し、`make generate` を実行して構成を同期させてください。これを怠ると、次回の `make deploy` 時にリソースの乖離（ドリフト）や意図しない削除が発生する原因となります。

#### ⚠️ 重要な注意: SSoT を経由せず手動追加したプロジェクトの「中央監視」と「ログ集約」

コンソールや `gcloud` で手動追加したプロジェクト（`gcp-foundations.xlsx` への追記＋`make generate` を行っていないもの）は、**中央監視とログ集約で挙動が正反対**になります。これは設計上の仕様です。

| 対象 | 手動追加プロジェクトの扱い | 理由 |
| :--- | :--- | :--- |
| **ログ集約シンク** | ✅ **自動的に対象になる** | 組織レベルのシンク（`google_logging_organization_sink`）を `include_children = true` で構成しており、**組織配下に作られたプロジェクトは経路を問わず**（コンソール手動でも）ログが集約先へ流れます。`make generate` は不要です。 |
| **中央監視（スコーピング）** | ❌ **対象にならない** | 監視スコープへの登録は **Push 型**（`google_monitoring_monitored_project`）で、**baseline モジュール経由でプロジェクトを作成したときにのみ**実行されます。手動追加したプロジェクトはこの登録が走らないため、**中央監視ダッシュボードやメトリクスベースのアラートに現れません**。 |

**運用上の意味:**

- **監査ログ（証跡）は取りこぼしません** — 手動追加プロジェクトでも組織シンクが自動的にログを捕捉します（セキュリティ統制上の重要な保証）。
- **監視は取りこぼします** — 「プロジェクトを作ったのに中央ダッシュボードに出てこない」の典型的な原因がこれです。コスト・パフォーマンスの中央可視化から抜け落ちます。
- **対処**: 手動追加したプロジェクトは、必ず `gcp-foundations.xlsx` に追記（既存 project_id は `existing_project_id` 列で採用(adopt)）し、`central_monitoring = TRUE` として `make generate` → `make deploy` を実行してください。これで監視スコープにも登録され、監視・ログ双方で整合が取れます。

______________________________________________________________________

## 3. 注意事項と運用ルール

### プロジェクト ID の命名規則

本基盤では、再現性を担保するために「企業名-環境-アプリ名」といった SSoT に基づく命名を徹底します。ランダムなサフィックスの使用は避けてください。

### 課金アカウントのリンク

GCP の仕様上、プロジェクト作成後に課金アカウントがリンクされていないと、API の有効化やリソースの作成（GCS バケットなど）が制限されます。本基盤の多くの処理（API 有効化・予算アラート・各種リソース）は「課金リンク済み」を前提としています。

#### 課金リンクの3モード（`billing_account` 列）

`gcp-foundations.xlsx` の `resources` シート `billing_account` 列で、プロジェクトごとに挙動を指定できます（詳細は [スプレッドシート仕様](../setup/spreadsheet_format.md) を参照）。

| 指定値 | 挙動 | 予算アラート |
| :--- | :--- | :--- |
| **空欄** | グローバル `billing_account_id` にリンク（採用(adopt)プロジェクトで空欄なら既存リンクを尊重し `manual` 扱い） | 作成される |
| **`manual`** | **Terraform は課金を管理しない**（手動リンク／既存リンク前提） | 作成されない |
| **`<課金アカウントID>`** | 指定アカウントにリンク | 作成される |

> 課金リンクは **作成時のみ**設定されます（project-factory 側で `ignore_changes = [billing_account]`）。既存プロジェクトの課金を Terraform が付け替え・解除することはありません。

#### `manual` の場合の手動リンク手順

`billing_account = manual` のプロジェクトは Terraform が課金をリンクしないため、**管理者が手動で**課金アカウントを紐付ける必要があります。

```bash
# 課金アカウントをリンク
gcloud billing projects link <PROJECT_ID> \
  --billing-account=<BILLING_ACCOUNT_ID>      # 例: 012345-6789AB-CDEF01

# 確認（billingEnabled: True であればOK）
gcloud billing projects describe <PROJECT_ID>
```

コンソールの場合: **お支払い → アカウント管理 →「プロジェクトをリンク」**、またはプロジェクトの **お支払い** 画面から。

**必要な権限（実行者に付与）:**

- 課金アカウント側: `roles/billing.user`（または `roles/billing.admin`）
- プロジェクト側: `roles/owner` もしくは `roles/resourcemanager.projectBillingManager`

**タイミングの注意:**

- **採用(adopt)した既存プロジェクト**（多くの `manual` はこれ）: すでにリンク済みのことが多く、その場合は**何もしなくてOK**。Terraform は課金に干渉しません。
- **新規プロジェクトで手動リンクしたい場合**: 新規作成は「プロジェクト作成 → 即 API 有効化」が同一 apply 内で走るため、**課金未リンクだと API 有効化で失敗**します（鶏卵問題）。この場合は ①先に対象プロジェクトだけ作成して手動リンク → その後 `make deploy` で残りを適用、もしくは ②`manual` を使わず `billing_account` にアカウントIDを指定（Terraform が作成時にリンク）する方が確実です。

#### apply 前の自動ガード

`make deploy`（`deploy_all.sh`）は `make generate` 後・apply 前に、`billing_account = manual` の全プロジェクトについて課金リンクの有無を検証します（`terraform/scripts/check_billing_links.sh`）。未リンクを検出した場合は **apply を実行せず停止**し、手動リンク用のコマンドを表示します。CI／認証情報なしの環境ではスキップされ、`make plan`（plan-only）では停止せず警告に留まります。

その他のトラブルシューティングは **[トラブルシューティング・ガイド](./troubleshooting.md)** を参照してください。

### プロジェクトの削除

プロジェクトを削除する場合は、**絶対にリポジトリルートやプロジェクトディレクトリで `terraform destroy` を実行しないでください。** 意図せず基盤全体や他の重要なリソースを削除してしまう恐れがあります。

安全にプロジェクトを削除するための手順と注意事項は以下の通りです。

1. **削除保護の解除 (事前準備)**:
   誤削除防止のため、初期状態では削除保護が有効になっています。削除を実行する前に、まずこの保護を無効化する必要があります。

   - 対象プロジェクトのディレクトリ（例: `terraform/4_projects/prd-app-01`）にある `terraform.tfvars` を編集します。
   - **※ `terraform.tfvars` が存在しない場合**: 後任者として引き継いだ直後などでファイルがない場合は、先に **[リカバリガイド](./recovery_and_succession.md)** を参照して設定ファイルを復元してください。
   - 以下の行の値を `false` に変更します。
     ```hcl
     deletion_protection = false
     ```
   - 一度 `apply` を実行して、GCP 上のプロジェクト設定を更新します。
     ```bash
     terraform apply -target=module.project
     ```

1. **特定のリソースのみをターゲットにして削除を実行**:
   保護が解除されたら、あらためて削除コマンドを実行します。

   ```bash
   # 特定のモジュール（プロジェクト本体）のみをターゲットにして削除を実行
   terraform apply -destroy -target=module.project
   ```

   ※ 関連する API 有効化設定も削除する場合は `-target=module.project_services` も併せて指定することを検討してください。

1. **スプレッドシート（SSoT）との整合性**:
   Terraform 上での削除が完了した後、`gcp-foundations.xlsx` から該当する行を削除してください。

1. **手動によるプロジェクトのシャットダウン**:
   Terraform でのリソース削除後、必要に応じて Google Cloud コンソールからプロジェクトの「シャットダウン」を手動で実行してください。

> **警告**: `terraform destroy` は現在のステート（状態ファイル）に含まれる**すべてのリソース**を削除対象とします。本基盤のようなマルチレイヤー構成では、一歩間違えると組織全体の基盤が消失する可能性があるため、原則として使用を禁止します。

### プロジェクトの安全なパージ（除外）と解体

本基盤では、プロジェクトを SSoT（Excel）から削除した際の「安全なパージ機能」と、GCP 上の実体を消し去る「完全解体」の明確な手順が定義されています。プロジェクトを削除する場合は、**絶対にリポジトリルートやプロジェクトディレクトリで単なる `terraform destroy` を実行しないでください。** 意図せず基盤全体が消失する恐れがあります。

#### 1. SSoT (Excel) から行を削除した際の挙動（安全なパージ）

Excel からプロジェクトの行を削除して `make generate` を実行すると、対象プロジェクトは自動的に以下の「パージ（隔離）」状態になります。

- **自動パージ**: 当該プロジェクト内の `terraform.tfvars` のみが自動削除され、以降の `make deploy` や `make destroy` の対象から完全に除外されます。
- **安全設計の理由**: 現場のエンジニアが独自に記述したインフラコード（`.tf` ファイル等）を誤って破壊しないための保護機能です。そのため、**ローカルのディレクトリや GCP 上の実リソースが自動的に削除されることはありません。**
- **警告メッセージ**: `make generate` 実行時、孤立したプロジェクトディレクトリが検出された場合は `⚠️ WARNING` または `ℹ️ INFO` メッセージが出力されます。GCP 上のリソースを解体した後、`make prune` でディレクトリを削除してください。

#### 2. リソースを完全に解体（Destroy）する場合の正しい手順

GCP 上の実体を解体する場合は、**Excel から行を消す前に**以下の正規手順を実行してください。

1. **削除保護の解除 (事前準備)**:
   対象ディレクトリ（例: `terraform/4_projects/prd-app-01`）の `terraform.tfvars` を開き、以下の値を `false` に変更します。

   ```hcl
   deletion_protection = false
   ```

   その後、一度 `apply` を実行して GCP 上の保護設定を解除します。

   ```bash
   terraform apply -target=module.project
   ```

   ※ `terraform.tfvars` が存在しない（引き継ぎ直後など）場合は、先に **[リカバリガイド](./recovery_and_succession.md)** を参照して復元してください。

1. **特定のリソースのみをターゲットにして解体を実行**:
   保護が解除されたら、あらためてプロジェクト本体のみをターゲットにして削除を実行します。

   ```bash
   terraform apply -destroy -target=module.project
   ```

   ※ 関連する API 有効化設定も削除する場合は `-target=module.project_services` も併せて指定してください。

1. **SSoT とローカルディレクトリの整理**:
   Terraform 上での解体が完了したことを確認してから、`gcp-foundations.xlsx` の該当行を削除し、`make generate` を実行してください。その後、以下のコマンドでローカルの孤立ディレクトリを対話形式で削除できます。

   ```bash
   make prune
   ```

   `make prune` は SSoT に存在しないプロジェクトディレクトリを一覧表示し、`PRUNE` と入力することで一括削除します。`terraform.tfvars` が残っているディレクトリ（GCP リソースがまだ存在する可能性あり）も警告付きで表示されます。

1. **手動によるプロジェクトのシャットダウン**:
   必要に応じて Google Cloud コンソールからプロジェクトの「シャットダウン」を手動で実行してください。

> **警告**: 単なる `terraform destroy` コマンドは現在のステートに含まれる**すべてのリソース**を削除対象とします。一歩間違えると組織全体の基盤が消失する可能性があるため、本基盤では原則として使用を禁止します。

______________________________________________________________________

## 4. テンプレート変更を既存プロジェクトへ反映（再スキャフォールド）

`make generate` は、各プロジェクトの**構造ファイル（`main.tf` / `variables.tf` など）を「初回作成時のみ」テンプレート（`terraform/4_projects/template/`）からコピー**します（scaffold-once）。毎回更新されるのは `terraform.tfvars` と `auto_global_vars.tf` だけです。

そのため、**テンプレート側に新しい変数の受け渡し（例: `budget_threshold_percents`）が追加されても、既存プロジェクトの `main.tf` / `variables.tf` には自動反映されません**。既存プロジェクトでその新機能（例: 予算アラート閾値の上書き）を有効にするには、構造ファイルを作り直す「再スキャフォールド」が必要です。

### いつ必要か

- テンプレート（`4_projects/template/`）が更新され、その新しい変数・配線を**既存**プロジェクトにも効かせたいとき。
- 例: `common.tfvars` に `budget_threshold_percents = [0.25, 0.5, 0.9, 1.0]` を設定したのに、既存プロジェクトの予算アラートが 3 段階のまま変わらない。

> 新規追加するプロジェクトはテンプレートが最新のため再スキャフォールド不要です。これは**既存**プロジェクトにのみ必要な作業です。

### 手順

```bash
# 1. 反映したいグローバル設定を common.tfvars に記入（例）
#    budget_threshold_percents = [0.25, 0.5, 0.9, 1.0]

# 2. 対象プロジェクトの構造ファイルだけを削除して作り直す
#    （<app_name> は対象プロジェクト名）
rm terraform/4_projects/<app_name>/main.tf \
   terraform/4_projects/<app_name>/variables.tf
make generate     # 最新テンプレートから main.tf / variables.tf を再コピー＋tfvars/auto を再生成

# 3. 差分確認 → 適用
make plan         # 期待した変更（例: 予算 threshold_rules の増減）のみであることを確認
make deploy
```

> ⚠️ 削除するのは **`main.tf` と `variables.tf` のみ**。`backend.tf`（tfstate バケットの prefix を保持）と `terraform.tfvars`（`make generate` が再生成）は**削除しないでください**。`terraform/4_projects/<app_name>/` は `.gitignore` 対象のため、これらはローカル操作のみでコミット不要です。

### 確認

```bash
# テンプレートの配線が入ったか（例）
grep budget_threshold_percents terraform/4_projects/<app_name>/main.tf
# → "budget_threshold_percents = var.budget_threshold_percents" が表示されれば反映済み
```
