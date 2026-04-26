# 共通基盤パラメータ データ定義書 (Data Dictionary)

本ドキュメントは、GCP基盤（Terraform IaC）の構築・運用において、ユーザーが入力または管理するすべてのパラメータ（データ定義）をまとめたものです。
本基盤は **Single Source of Truth (SSOT)** の原則に基づき、各ファイル（Excel, CSV, ENV）で定義された値がトップダウンでシステム全体へ伝播するアーキテクチャを採用しています。

## 1. 初期セットアップ変数 (Interactive Input)

基盤構築の「初日」に `make setup`（内部的に `setup_new_client.sh`）を通じて対話形式で入力する最上位のパラメータです。

| 物理名 (変数名) | 論理名 | 必須 | 型 | 設定例 | 備考 |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `CUSTOMER_DOMAIN` | 顧客プライマリドメイン | 必須 | String | `example.com` | 管理対象となるGCP組織のドメイン。 |
| `GCP_REGION` | デフォルトGCPリージョン | 必須 | String | `asia-northeast1` | インフラ全体の基準リージョン。 |
| `ENABLE_VPC` | Shared VPC 有効化 | 任意 | Boolean | `true` | 共通 VPC ネットワーク基盤を構築するか。 |
| `ENABLE_VPC_SC` | VPC-SC 有効化 | 任意 | Boolean | `false` | セキュリティ境界（Perimeter）を有効にするか。 |
| `ENABLE_ORG_POLICIES`| 組織ポリシー 有効化 | 任意 | Boolean | `false` | 組織全体のガードレールを有効にするか。 |

______________________________________________________________________

## 2. プロジェクト構成データ (SSOT)

メインの管理ファイルである `gcp_foundations.xlsx` で定義するパラメータです。

### シート: `resources` (プロジェクト/フォルダ一覧)

| 物理名 (カラム名) | 論理名 | 型 | 設定例 | 備考 |
| :--- | :--- | :--- | :--- | :--- |
| `resource_type` | リソース種別 | String | `project` | `folder` または `project` を指定。 |
| `parent_name` | 親リソース名 | String | `shared` | 親フォルダ名、または組織直下なら `organization_id`。 |
| `resource_name` | リソース名 | String | `prd-app-01` | フォルダ表示名、またはアプリ名。 |
| `shared_vpc` | 使用サブネット名 | String | `prd-subnet-01` | `shared_vpc_subnets` シートで定義した名前。 |
| `vpc_sc` | 所属境界名 | String | `default_perimeter` | `vpc_sc_perimeters` シートで定義した名前。 |
| `monitoring` | 監視対象フラグ | Boolean | `TRUE` | Cloud Monitoring による監視を行うか。 |
| `logging` | ログ集約フラグ | Boolean | `TRUE` | 組織ログシンクによる収集を行うか。 |
| `billing_linked` | 課金リンク完了フラグ | Boolean | `FALSE` | **TRUE** に変更すると API 有効化が実行されます。 |
| `project_apis` | 有効化 API リスト | String | `compute.googleapis.com` | カンマ区切りの API リスト。 |

### その他の詳細設定シート
- **`shared_vpc_subnets`**: サブネット名、IP範囲、リージョンの定義。
- **`vpc_sc_perimeters`**: サービス境界名、保護対象サービスの定義。
- **`vpc_sc_access_levels`**: ホワイトリスト（IP/SA）の定義。
- **`org_policies`**: 適用先、ポリシーID、強制/許可リストの定義。

______________________________________________________________________

## 3. ログ・アラート定義データ (CSV)
（※ 詳細な仕様や記入方法については、**[スプレッドシートの仕様書](../reference/spreadsheet_format.md)** を参照してください）

______________________________________________________________________

## 4. システム自動連携変数 (System-Managed)

自動化スクリプト（`make setup` / `make generate`）によって生成され、`common.tfvars` に出力される共通変数です。

| 物理名 (変数名) | 論理名 | 型 | 説明 |
| :--- | :--- | :--- | :--- |
| `terraform_service_account_email`| TF実行用SA | String | 管理用サービスアカウントのメールアドレス。 |
| `gcs_backend_bucket` | tfstateバケット | String | 状態ファイルを保存する GCS バケット。 |
| `organization_domain`| 組織ドメイン | String | 顧客のプライマリドメイン名。 |
| `gcp_region` | 基準リージョン | String | インフラ全体のデフォルトリージョン。 |
| `project_id_prefix` | プロジェクト接頭辞 | String | ドメインから算出された安全な接頭辞。 |
| `core_billing_linked`| コア課金完了フラグ | Boolean | 共通基盤プロジェクトの課金準備が整ったか。 |
| `enable_shared_vpc` | Shared VPC グローバル | Boolean | 全体で Shared VPC 機能を使うか。 |
| `enable_vpc_sc` | VPC-SC グローバル | Boolean | 全体で VPC-SC 機能を使うか。 |
| `enable_org_policies`| 組織ポリシー グローバル| Boolean | 全体で組織ポリシーを適用するか。 |
