# GCP Foundations テスト計画書

## 1. はじめに

### 1.1. 目的

本ドキュメントは、`gcp-foundations`リポジトリで管理されるIaC(Infrastructure as Code)基盤の品質、セキュリティ、および運用上の信頼性を保証するためのテスト計画を定義する。

本テストは、コード上の論理的な正しさに加え、実際のGCPリソースが意図通りに構成され、かつ設計されたガバナンス機構が有効に機能することをエンドツーエンドで検証することを目的とする。

### 1.2. 範囲

- **対象**: `main`ブランチの最新コード。リポジトリに含まれる全レイヤーのTerraformコード、自動生成スクリプト、CI/CDワークフロー、および関連ドキュメント。
- **対象外**: GCP自体の障害、サードパーティ製Terraformプロバイダのバグ。

### 1.3. テストレベル

- **単体テスト**: `pytest`によるPythonスクリプトのロジック検証（実施済み）。
- **静的解析**: `tflint`, `checkov`, `shellcheck`によるコードスキャン（CIで自動化済み）。
- **結合テスト**: Terraformの各レイヤーを個別にデプロイし、そのレイヤーの責務が正しく果たされるかを確認する。
- **システム/E2Eテスト**: `make deploy`を用いてゼロから全レイヤーをデプロイし、機能横断的なシナリオ（例: 非アクティブアカウント検知）が正常に動作するかを検証する。

## 2. テスト環境

- **GCP**: 本番環境とは完全に分離された、テスト専用のGCP組織（Organization）。
- **ツール**: `gcloud` CLI, `terraform` (v1.6+), `make`, `uv`がインストールされた実行環境。
- **認証**: テスト用GCP組織に対する組織管理者および請求先アカウント管理者の権限を持つユーザーアカウント。

## 3. テスト項目

### 3.1. SSoT とコード生成

| ID | 機能エリア | テスト概要 | 前提条件 | テスト手順 | 期待結果 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| TC-GEN-01 | バリデーション | **異常系**: `gcp-foundations.xlsx`に意図的に不正な値（重複プロジェクト名、CIDR重複、存在しない親フォルダ等）を入力する。 | - | `make generate`を実行する。 | スクリプトはエラーを検知して異常終了し、Terraformファイルが生成されないこと。エラーメッセージが分かりやすいこと。 |
| TC-GEN-02 | `tag_definitions` | **正常系**: `tag_definitions`シートに新しいタグを定義し、`resources`シートの`org_tags`列でそのタグをフォルダ/プロジェクトに割り当てる。 | - | `make generate`を実行し、`terraform/2_organization/auto_tags.tf`と`terraform/4_projects/.../main.tf`を確認。`make deploy`で適用。 | `auto_tags.tf`に`google_tags_tag_key`等が作成されること。GCPコンソールで対象リソースにタグが正しく紐付いていること。 |
| TC-GEN-03 | `log_sinks` | **正常系**: `log_sinks.csv`に新しいログ集約定義（BigQuery/GCS）を追加する。 | - | `make generate`を実行し、`terraform/1_core/services/logsink/sinks/locals.tf`の解釈を確認。`make deploy`で適用。 | `locals.tf`で定義が読み込まれること。GCPコンソールで組織レベルのログシンクと宛先リソースが作成されていること。 |

### 3.2. 初期構築とライフサイクル

| ID | 機能エリア | テスト概要 | 前提条件 | テスト手順 | 期待結果 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| TC-LC-01 | `make setup` | **正常系**: クリーンなリポジトリで`make setup`を対話的に実行する。 | `gcloud auth login`済み。 | スクリプトの質問に回答し、途中で求められる課金アカウントのリンクを手動で行う。 | スクリプトが正常に完了し、管理プロジェクト、tfstateバケット、Terraform用SAが作成されること。`common.tfvars`等のファイルが生成されること。 |
| TC-LC-02 | `make deploy` | **正常系**: `make setup`完了後、`gcp-foundations.xlsx`に基本的なリソース（フォルダ1つ、プロジェクト1つ）を定義し、`make deploy`を実行する。 | TC-LC-01完了。 | `make deploy`を実行する。 | エラーなく完了し、定義したフォルダとプロジェクトがGCPコンソールで確認できること。 |
| TC-LC-03 | 課金未設定 | **異常系**: `make setup`後、課金アカウントをリンクせず、`common.tfvars`の`core_billing_linked`を`false`のまま`make deploy`を実行する。 | TC-LC-01の途中で課金リンクをスキップ。 | `make deploy`を実行する。 | `deploy_all.sh`がAPI有効化を含む`1_core/services`レイヤーを安全にスキップし、エラーを発生させずに完了すること。 |
| TC-LC-04 | 差分適用 | **正常系**: TC-LC-02完了後、Excelに新しいプロジェクトを1つ追加し、再度`make deploy`を実行する。 | TC-LC-02完了。 | Excelに行を追加し、`make generate`後に`make deploy`。 | 既存のリソースに変更（`No changes`）はなく、新しいプロジェクトのみが追加（`1 to add`）されること。 |
| TC-LC-05 | リソース削除 | **安全な削除手順**: `docs/operations/project_lifecycle.md`に従い、プロジェクトを安全に削除する。 | TC-LC-04完了。 | 1. `deletion_protection=false`設定。2. `terraform apply -destroy -target=...`実行。 | 対象プロジェクトのみがTerraformの管理下から削除・GCPから破棄されること。他のリソースに影響がないこと。 |

### 3.3. セキュリティ & ガバナンス

| ID | 機能エリア | テスト概要 | 前提条件 | テスト手順 | 期待結果 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| TC-SEC-01 | 組織ポリシー | **ベースライン適用**: `enable_org_policies = true`でデプロイ後、GCPコンソールから手動でサービスアカウントキーを作成しようとする。 | `enable_org_policies=true`。 | プロジェクトのIAMページでSAキーを作成。 | 「組織のポリシーによって制限されています」というエラーが表示され、キーが作成できないこと。 |
| TC-SEC-02 | フォルダ別ポリシー | **位置情報制約**: Excelの`org_policies`シートで`production`フォルダに`gcp.resourceLocations`を`asia-northeast1`に設定しデプロイ。 | TC-SEC-01完了。 | `production`フォルダ内のプロジェクトで、`us-central1`にGCSバケットを作成しようとする。 | ポリシー違反のエラーで作成が失敗すること。`asia-northeast1`では成功すること。 |
| TC-SEC-03 | VPC-SC | **境界防御**: `enable_vpc_sc = true`でデプロイ後、VPC-SC境界内のVMから、保護対象のGCSバケットにあるオブジェクトを`gsutil cp`でローカルマシンにコピーしようとする。 | `enable_vpc_sc=true`。境界内プロジェクトにVM作成済み。 | `gcloud compute ssh`でVMに入り、`gsutil`コマンドを実行。 | データ持ち出しがブロックされ、`Request is prohibited by organization's policy`エラーが発生すること。 |
| TC-SEC-04 | IAMモデル | **権限分離**: 9グループモデルでデプロイし、`gcp-developers`グループに所属するテストユーザーでログインする。 | 9グループモデルでデプロイ済み。 | テストユーザーでプロジェクトのVMインスタンスを作成・削除しようとする。 | 閲覧は可能だが、作成・削除は権限不足で失敗すること。 |

### 3.4. E2E機能テスト

| ID | 機能エリア | テスト概要 | 前提条件 | テスト手順 | 期待結果 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| TC-E2E-01 | 非アクティブアカウント監視 | **検知フロー**: 1. テストユーザーを作成し、プロジェクトに権限を付与。2. 90日待たずに`inactive_users_view`の条件（日付部分）を一時的に「1日」に変更してデプロイ。3. `inactive-account-reporter`関数を手動実行。 | `make deploy`完了済み。 | BigQueryでViewのSQLを書き換えて`apply`。Cloud Functionsのコンソールから関数をテスト実行。 | 1. Cloud Monitoringの`inactive_account_count`が1になる。2. アラートが発報され、`notifications.csv`で定義したメールアドレスに通知が届く。 |
| TC-E2E-02 | ログベースアラート | **発報フロー**: 1. `alert_definitions.csv`に`severity="CRITICAL"`という条件で新しいアラートを定義。2. 監視対象プロジェクトで手動で`CRITICAL`レベルのログを生成。 | `make deploy`完了済み。 | `gcloud logging write`コマンドでテストログを書き込む。 | 5〜10分以内にアラートが発報され、通知先にメールが届くこと。 |

## 4. 今後の課題

- **テスト自動化**: 本計画書の多くのテスト項目は手動実行を前提としている。特に「SSoTとコード生成」の異常系テストや、「セキュリティ」の各テストシナリオは、[Terratest](https://terratest.gruntwork.io/)のようなフレームワークを導入し、CI/CDパイプラインに組み込むことで、回帰テストを自動化することが望ましい。
- **コスト変動テスト**: 予算アラート機能のE2Eテストは、実際にコストを発生させる必要があり、時間がかかるため本計画では手動での設定確認に留めている。疑似的なコストデータを注入するなどのシミュレーション手法を検討する。
