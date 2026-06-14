# 共通基盤パラメータ データ定義書 (Data Dictionary)

本ドキュメントは、GCP基盤（Terraform IaC）の構築・運用において、ユーザーが入力または管理するすべてのパラメータ（データ定義）をまとめたものです。
本基盤は **Single Source of Truth (SSoT)** の原則に基づき、各ファイル（Excel, CSV, ENV）で定義された値がトップダウンでシステム全体へ伝播するアーキテクチャを採用しています。

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

## 2. プロジェクト構成データ (SSoT)

メインの管理ファイルである `gcp-foundations.xlsx` で定義するパラメータです。

### シート: `resources` (プロジェクト/フォルダ一覧)

| 物理名 (カラム名) | 論理名 | 型 | 設定例 | 備考 |
| :--- | :--- | :--- | :--- | :--- |
| `resource_type` | リソース種別 | String | `project` | `folder` または `project` を指定。 |
| `parent_name` | 親リソース名 | String | `shared` | 親フォルダ名、または組織直下なら `organization_id`。 |
| `resource_name` | リソース名 | String | `prd-app-01` | フォルダ表示名、またはアプリ名。 |
| `environment` | 環境 | String | `prod` | `prod`/`stag`/`dev` のいずれか、または**空欄（任意）**。指定時のみ `env` ラベルが付与される。名前からの推定はしない。`shared_vpc` 利用時のみ必須。 |
| `shared_vpc` | 使用サブネット名 | String | `prd-subnet-01` | `shared_vpc_subnets` シートで定義した名前。 |
| `vpc_sc` | 所属境界名 | String | `default_perimeter` | `vpc_sc_perimeters` シートで定義した名前。 |
| `central_monitoring` | 監視対象フラグ | Boolean | `TRUE` | Cloud Monitoring による監視を行うか。 |
| `central_logging` | ログ集約フラグ | Boolean | `TRUE` | 組織ログシンクによる収集を行うか。 |

> **💡 `environment` の扱い**（`make generate`）:
> - **任意**。指定する場合は `prod`/`stag`/`dev` のみ（許可外はエラー）。**名前(`resource_name`)からの推定は一切しない**（名前と環境を分離）。
> - **空欄なら `env` ラベルを付与しない**（ラベルなしを許容。OPA も `env` を必須にしない）。
> - **`shared_vpc` を使う行のみ `environment` が必須**（接続先ホスト prod/dev の判定に必要）。
> - 表示名(`name`)は `app_name` をそのまま使い、**環境サフィックスは付与しない**（旧 `app-dev` のような自動付与を廃止）。

> **💡 `shared_vpc_env`（システム自動生成）**: `shared_vpc` 指定時、接続先 Shared VPC ホストを示す `shared_vpc_env` が `terraform.tfvars` に出力されます。**決定済みの `environment` から導出**（`dev`→`dev` ホスト／`prod`・`stag`→`prod` ホスト）、`shared_vpc` 未指定なら `none`。ホストプロジェクトは **`prod` / `dev` の2つのみ**のため、`stag` は `prod` 側ホストに相乗りします（`env` ラベルが `stag` でも接続先ホストは `prod`）。命名接頭辞ではなく `environment` に依存する点が以前との違いです。

### その他の詳細設定シート

- **`shared_vpc_subnets`**: サブネット名、IP範囲、リージョンの定義。
- **`vpc_sc_perimeters`**: サービス境界名、保護対象サービスの定義。
- **`vpc_sc_access_levels`**: ホワイトリスト（IP/SA）の定義。
- **`org_policies`**: 適用先（`target_name`）、ポリシーID、強制（`enforce`）/許可リスト（`allow_list`）、適用モード（`apply_mode`: `live` / `dryrun` / `both`、空欄は `live`）の定義。`apply_mode` で本番強制（`spec`）と DryRun（`dry_run_spec`）をターゲット別に出し分けられる。

______________________________________________________________________

## 3. ログ・アラート定義データ (CSV)

（※ 詳細な仕様や記入方法については、**[スプレッドシートの仕様書](../setup/spreadsheet_format.md)** を参照してください）

______________________________________________________________________

## 4. システム自動連携変数 (System-Managed)

自動化スクリプト（`make setup` / `make generate`）によって生成され、`common.tfvars` に出力される共通変数です。

| 物理名 (変数名) | 論理名 | 型 | 説明 |
| :--- | :--- | :--- | :--- |
| `terraform_service_account_email`| TF実行用SA | String | 管理用サービスアカウントのメールアドレス。 |
| `gcs_backend_bucket` | tfstateバケット | String | 状態ファイルを保存する GCS バケット。 |
| `organization_domain`| 組織ドメイン | String | 顧客のプライマリドメイン名。 |
| `gcp_region` | 基準リージョン | String | インフラ全体のデフォルトリージョン。 |
| `project_id_prefix` | プロジェクト接頭辞 | String | ドメインから算出された安全な接頭辞。**2〜14文字、先頭は英字、末尾ハイフン不可**（例: `ea`, `myco`）。 |
| `enable_group_iam` | グループIAM有効化 | Boolean | Googleグループへの組織レベルIAM付与を行うか。グループ未作成時は `false` に設定し、グループ作成後に `true` へ変更して再デプロイする。 |
| `enable_shared_vpc` | Shared VPC グローバル | Boolean | 全体で Shared VPC 機能を使うか。 |
| `enable_vpc_sc` | VPC-SC グローバル | Boolean | 全体で VPC-SC 機能を使うか。 |
| `enable_org_policies`| 組織ポリシー グローバル| Boolean | 全体で組織ポリシーを適用するか。 |
| `billing_account_id` | 請求先アカウントID | String | `make setup` 時に自動設定されます。予算アラート等の紐付けに使用。 |

______________________________________________________________________

## 5. GCP プロジェクトラベル (Labels)

`make generate` によって生成される各プロジェクトには、以下のラベルが付与されます。**`owner` と `app` は必須**（CI の OPA で強制）。**`env` は任意**（`environment` 空欄なら付与されない）。

| ラベルキー | 必須 | 値の内容 | 値の生成元 |
| :--- | :---: | :--- | :--- |
| `env` | 任意 | `prod` / `stag` / `dev` | `resources` シートの `environment` 列（空欄ならラベルなし。section 2 参照） |
| `owner` | 必須 | 所有者を示す識別子 | Excel `resources` シートの `owner` 列（`^[a-z0-9_-]{1,63}$` 形式） |
| `app` | 必須 | アプリ名 | Excel `resources` シートの `resource_name` 列 |

### OPA による強制の仕組み

ポリシーファイルは `policies/require_labels.rego` に定義されています。CI の PR チェック時に以下の流れで実行されます。

```
1. terraform plan -out=tfplan
2. terraform show -json tfplan > plan.json
3. opa eval -d policies/ -i plan.json "data.terraform.validation.deny"
   → deny セットが空   → デプロイ続行
   → deny セットに値あり → CI 失敗・マージブロック
```

OPA は `google_project` リソースの作成・更新時に **`owner` / `app` ラベルが存在するか**を検査します（`env` は任意のため対象外）。削除アクションはチェック対象外です。値の内容（例: `prod` が正しいかどうか）は現時点では検査しません。
