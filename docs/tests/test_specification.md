# GCP Foundations テスト仕様書

## 1. はじめに

### 1.1. 目的

本ドキュメントは、[テスト計画書](./テスト計画書.md)および[テスト設計書](./テスト設計書.md)に基づき、`gcp-foundations`リポジトリの各機能が仕様通りに動作することを確認するための、詳細なテストケース（手順、入力、期待結果）を定義する。

### 1.2. 参照ドキュメント

- [GCP Foundations テスト計画書](./テスト計画書.md)
- [GCP Foundations テスト設計書](./テスト設計書.md)

---

## 2. テストケース

### 2.1. SSoT とコード生成

| テストケースID | テスト内容 | 前提条件 | 手順 | 入力データ | 期待結果 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-GEN-01-01** | SSoTバリデーション - `resources`シート内のプロジェクト名の重複 | テスト用のExcelファイル`validation-error-duplicate-project.xlsx`が`tests/fixtures/`に準備されている。 | 1. `tests/fixtures/validation-error-duplicate-project.xlsx` をリポジトリルートに `gcp-foundations.xlsx` としてコピーする。<br>2. ターミナルで `make generate` を実行する。 | `resources`シートに、`resource_type`が`project`で、`resource_name`が同一（例: `prd-app-01`）の行が2つ存在するExcelファイル。 | 1. `make generate`コマンドが終了コード`1`で失敗する。<br>2. 標準出力に「Configuration errors detected:」というヘッダーが表示される。<br>3. エラー詳細に「Duplicate name 'prd-app-01'」といった趣旨のメッセージが含まれていること。 |
| **TC-GEN-01-02** | SSoTバリデーション - `shared_vpc_subnets`シート内のCIDR重複 | テスト用のExcelファイル`validation-error-cidr-overlap.xlsx`が`tests/fixtures/`に準備されている。 | 1. `tests/fixtures/validation-error-cidr-overlap.xlsx` をリポジトリルートに `gcp-foundations.xlsx` としてコピーする。<br>2. ターミナルで `make generate` を実行する。 | `shared_vpc_subnets`シートに、`ip_cidr_range`が重複する（例: `10.0.1.0/24`と`10.0.1.128/25`）行が2つ存在するExcelファイル。 | 1. `make generate`コマンドが終了コード`1`で失敗する。<br>2. 標準出力に「Configuration errors detected:」というヘッダーが表示される。<br>3. エラー詳細に「CIDR '10.0.1.128/25' overlaps with '10.0.1.0/24'」といった趣旨のメッセージが含まれていること。 |

### 2.2. 初期構築とライフサイクル

| テストケースID | テスト内容 | 前提条件 | 手順 | 入力データ | 期待結果 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-LC-02-01** | 初期デプロイ（Happy Path）と差分適用 | ・テスト用GCP組織。<br>・実行環境で`gcloud auth login`済み。<br>・`happy-path.xlsx`が準備済み。 | 1. `make setup`を実行し、対話形式で設定を完了させる（課金アカウントのリンクも含む）。<br>2. `happy-path.xlsx`を`gcp-foundations.xlsx`としてコピーする。<br>3. `make deploy`を実行する。<br>4. `gcp-foundations.xlsx`の`resources`シートに、新しい`project`を1行追加する。<br>5. `make generate`を実行する。<br>6. `make deploy`を再度実行する。 | `happy-path.xlsx`: `shared`フォルダ1つと`prd-app-01`プロジェクト1つが定義されている。 | 1. 手順3の`make deploy`がエラーなく完了すること。<br>2. GCPコンソールで`shared`フォルダと`prd-app-01`プロジェクトが作成されていることを確認する。<br>3. 手順6の`make deploy`のログ上で、既存リソースが`No changes`となり、新規プロジェクトのみが`1 to add`として計画・適用されること。 |

### 2.3. セキュリティ & ガバナンス

| テストケースID | テスト内容 | 前提条件 | 手順 | 入力データ | 期待結果 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-SEC-02-01** | フォルダ別組織ポリシー - リソースロケーション制限 | ・`common.tfvars`の`enable_org_policies`が`true`に設定されている。<br>・`gcp-foundations.xlsx`の`org_policies`シートで`target_name`が`production`フォルダ、`policy_id`が`gcp.resourceLocations`、`allow_list`が`asia-northeast1`に設定されている。<br>・上記設定で`make deploy`が完了している。<br>・`production`フォルダ配下に`prd-sec-test-01`プロジェクトが存在する。 | 1. `gcloud config set project prd-sec-test-01`でプロジェクトを切り替える。<br>2. `gcloud storage buckets create gs://prd-sec-test-us-bucket --location=us-central1` を実行する。<br>3. `gcloud storage buckets create gs://prd-sec-test-jp-bucket --location=asia-northeast1` を実行する。 | - | 1. 手順2のコマンドが`Constraint "gcp.resourceLocations" violated`というエラーで失敗すること。<br>2. 手順3のコマンドが成功すること。 |
| **TC-SEC-03-01** | VPC-SC - 境界外へのデータ持ち出し禁止 | ・`common.tfvars`の`enable_vpc_sc`が`true`に設定されている。<br>・`vpc_sc_perimeters`シートで`default_perimeter`が定義され、`storage.googleapis.com`が`restricted_services`に含まれている。<br>・`resources`シートで`prd-sc-test-01`プロジェクトが`default_perimeter`に所属するように定義されている。<br>・上記設定で`make deploy`が完了している。<br>・`prd-sc-test-01`プロジェクト内にGCE-VMとGCSバケットが作成され、バケットにはテストファイル`test.txt`が配置されている。 | 1. `gcloud compute ssh`でVMにログインする。<br>2. VM上で`gcloud auth login`を実行し、ユーザー認証を行う。<br>3. `gsutil cp gs://<バケット名>/test.txt .` を実行する。 | - | 1. `gsutil`コマンドが`Request is prohibited by organization's policy.`というエラーで失敗すること。 |

### 2.4. E2E機能テスト

| テストケースID | テスト内容 | 前提条件 | 手順 | 入力データ | 期待結果 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-E2E-01-01** | 非アクティブアカウント監視 - 検知とアラート | ・`make deploy`が完了している。<br>・テストユーザー`test-inactive-user@<domain>`が作成され、いずれかのプロジェクトの閲覧者(`roles/viewer`)権限が付与されている。 | 1. GCPコンソールのBigQuery画面を開く。<br>2. `logsink`プロジェクトの`security_analytics`データセットにある`inactive_users_view`を探す。<br>3. ビューのクエリを編集し、`INTERVAL 90 DAY`の部分を`INTERVAL 1 MINUTE`に変更して保存する。<br>4. 2分程度待機する。<br>5. Cloud Schedulerコンソールを開き、`daily-inactive-account-check`ジョブを手動で「今すぐ実行」する。<br>6. Cloud Monitoringコンソールを開き、Metrics Explorerで`custom.googleapis.com/security/inactive_account_count`という指標を検索する。 | - | 1. 手順6で、指標の値が `1` 以上でプロットされていることを確認する。<br>2. 5〜10分以内に、`notifications.csv`で定義された通知先に「Inactive User Account Detected」という件名のアラートメールが届くこと。 |
