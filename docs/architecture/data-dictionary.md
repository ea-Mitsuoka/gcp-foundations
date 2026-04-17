# 共通基盤パラメータ データ定義書 (Data Dictionary)

本ドキュメントは、GCP基盤（Terraform IaC）の構築・運用において、ユーザーが入力または管理するすべてのパラメータ（データ定義）をまとめたものです。
本基盤は **Single Source of Truth (SSOT)** の原則に基づき、各ファイル（Excel, CSV, ENV）で定義された値がトップダウンでシステム全体へ伝播するアーキテクチャを採用しています。

## 1. 初期セットアップ変数 (Interactive Input)

基盤構築の「初日」に `setup_new_client.sh` を通じて対話形式で入力する最上位のパラメータです。ここで入力された値は `domain.env` および各種 `.tfvars` に記録され、永続化されます。

| 物理名 (変数名) | 論理名 | 必須 | 型 | 設定例 | 備考 |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `CUSTOMER_DOMAIN` | 顧客プライマリドメイン | 必須 | String | `adradarstore.online` | 管理対象となるGCP組織のドメイン。プロジェクト命名規則の起点となります。 |
| `GCP_REGION` | デフォルトGCPリージョン | 必須 | String | `asia-northeast1` | GCSバケット、Cloud Functions、BigQueryなどを配置する基準リージョンです。 |

______________________________________________________________________

## 2. プロジェクト構成データ (SSOT)

顧客や運用担当者が日常的な運用（Day 2オペレーション）でプロジェクトを払い出すために更新する、メインの管理ファイルです。

### ファイル: `projects_config.xlsx`

| 物理名 (カラム名) | 論理名 | 必須 | 型 | 設定例 | 備考 |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `app_name` | アプリケーション名 | 必須 | String | `web-frontend` | 作成されるTerraformのディレクトリ名、およびプロジェクトIDの一部になります。 |
| `env` | 環境名 | 必須 | String | `dev` | `dev`, `stag`, `prod` など。プロジェクトIDの一部になります。 |
| `folder_id` | 親フォルダID | 任意 | String | `123456789012` | プロジェクトの配置先。空欄の場合は組織の直下に作成されます。 |
| `billing_linked` | 課金リンク状態フラグ | 必須 | Boolean | `FALSE` | 手動で課金アカウントをリンクしたかを示すトグル。`TRUE` でAPI有効化処理が走ります。 |
| `project_apis` | 有効化APIリスト | 任意 | String | `compute.googleapis.com,...` | プロジェクトで有効化したいGCP APIのリスト（複数ある場合はカンマ区切り）。 |

______________________________________________________________________

## 3. ログ・監視定義データ (CSV)

組織全体のログ集約ルール、および監視・アラートのルールを定義するファイル群です。これらを更新してスクリプトを回すことで、組織全体のガバナンス状態をアップデートできます。

### 3-1. 組織ログシンク構成 (`1_core/services/logsink/sinks/gcp_log_sink_config.csv`)

| 物理名 (カラム名) | 論理名 | 必須 | 型 | 設定例 | 備考 |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `log_type` | ログ種別 | 必須 | String | `管理アクティビティ監査ログ` | 運用者が判別しやすい日本語のログ種別名。 |
| `filter` | ログ抽出フィルタ | 必須 | String | `protoPayload.methodName="..."` | Cloud Logging の高度なフィルタリングクエリ。 |
| `destination_type` | 宛先リソース種別 | 必須 | String | `BigQuery` | `BigQuery` または `Cloud Storage` のいずれかを指定。 |
| `destination_parent` | 宛先リソース名 | 必須 | String | `admin_activity_audit_logs` | 保存先バケット名やデータセット名のベースとなる識別子。 |
| `retention_days` | ログ保持期間（日） | 必須 | Integer| `400` | この日数に基づき、GCSのライフサイクルやBQテーブル有効期限が自動設定されます。 |

### 3-2. アラートポリシー定義 (`1_core/services/monitoring/2_alert_policies/logsink_log_alerts/alert_definitions.csv`)

| 物理名 (カラム名) | 論理名 | 必須 | 型 | 設定例 | 備考 |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `alert_name` | アラートID | 必須 | String | `critical_error_alert` | システム内部での一意な識別子（英数字・スネークケース推奨）。 |
| `alert_display_name` | アラート表示名 | 必須 | String | `システム重大エラー検知` | Cloud Monitoring のコンソール画面に表示される名前。 |
| `metric_filter` | アラート発報フィルタ | 必須 | String | `severity >= ERROR` | アラートのトリガーとなるログのフィルタ条件。 |
| `alert_documentation`| アラート対応手順 | 任意 | String | `エラーログを確認して...` | 通知の本文に含まれるテキスト（Markdown対応）。運用者の初動手順を記載します。 |

### 3-3. 通知チャネル構成 (`.../logsink_log_alerts/notifications.csv`)

| 物理名 (カラム名) | 論理名 | 必須 | 型 | 設定例 | 備考 |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `user_email` | 通知先メールアドレス | 必須 | String | `admin@example.com` | アラートの送信先となるメールアドレス。 |
| `receive_alerts` | 通知有効化フラグ | 必須 | Boolean| `TRUE` | このメールアドレスへの通知を有効にするかのトグルスイッチ（TRUE/FALSE）。 |
| `project_id` | 監視対象プロジェクトID | 必須 | String | `example-logsink` | アラートを検知する対象のプロジェクトID。 |
| `alert_name` | 受信アラートID | 必須 | String | `critical_error_alert` | 受け取りたいアラートのID（`alert_definitions.csv` の `alert_name` と完全一致させる）。 |

______________________________________________________________________

## 4. システム自動連携変数 (System-Managed)

自動化スクリプトによって生成され、Terraformの実行コンテキストに注入される変数群です。**人間が手動で編集・管理する必要はありませんが、アーキテクチャの内部結合を担う重要なパラメータです。**

### ファイル: `common.tfvars` / 各ディレクトリの `terraform.tfvars`

| 物理名 (変数名) | 論理名 | 生成元 | 型 | 設定例/備考 |
| :--- | :--- | :--- | :--- | :--- |
| `terraform_service_account_email`| TF実行用SAアドレス | `setup_new_client.sh` | String | Terraformが権限を借用（Impersonation）するSA。 |
| `gcs_backend_bucket` | tfstate保存バケット | `setup_new_client.sh` | String | Terraformの `.tfstate` を一元管理するGCSバケット名。 |
| `organization_domain`| 組織ドメイン名 | `setup_new_client.sh` | String | 組織のリソース検索などに使用されるドメイン情報。 |
| `gcp_region` | デフォルトGCPリージョン | `setup_new_client.sh` | String | インフラ全体の基準となるGCPリージョン。 |
| `project_id_prefix` | プロジェクト接頭辞 | `setup_new_client.sh` | String | GCPのプロジェクトID 30文字制限を回避するため、ドメイン名から自動算出された安全な接頭辞。 |
| `core_billing_linked`| コア課金リンク状態フラグ| `setup_new_client.sh` | Boolean| `logsink` と `monitoring` の課金がリンクされたかを示すトグル（唯一、初期構築時に人間が一度だけ `true` に書き換える）。 |
| `project_id` | 管理用プロジェクトID | `setup_new_client.sh` | String | `0_bootstrap` 配下の `terraform.tfvars` にのみ出力される、TF管理用プロジェクトのID。 |

______________________________________________________________________

これにて、基盤の入力から出力に至るすべてのデータ構造が完璧に可視化されました。この設計書があれば、後任のSREや顧客のインフラ担当者も、どこを触ればシステムがどう動くかを瞬時に理解できるはずです。
