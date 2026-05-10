# GCP Foundations テスト仕様書

## 1. はじめに

本ドキュメントは、GCP Foundations IaC基盤の品質、整合性、およびガバナンス統制を検証するための詳細なテストケースと手順を定義します。最小構成から複雑なガバナンス構成、異常系バリデーション、および実運用を想定したライフサイクル管理までを網羅し、各ケースの具体的な実行コマンドを明記します。

## 2. テスト前提条件

テストの実行には以下の環境が整っている必要があります。

- Google Cloud 組織管理者権限を持つアカウントでの認証 (`gcloud auth login`, `gcloud auth application-default login`, `gcloud config set project PROJECT_ID`)
- `uv` (Pythonパッケージマネージャ) および `terraform` (1.5.0以上) のインストール
- `0_bootstrap` レイヤーの適用完了 (tfstate用バケットが存在すること)

## 2.1. テストデータの準備手順

各テストケース、特にPhase 1以降のケースを実行する際は、対応するテストデータを準備する必要があります。

1. 実行したいテストケースID（例: `TC-004`）を確認します。
1. `tests/fixtures/` ディレクトリから、そのテストケース番号を含むExcelファイル（例: `TC004_to_009_Validation_Err.xlsx`）を探します。
1. そのファイルをリポジトリのルートディレクトリにコピーし、ファイル名を **`gcp-foundations.xlsx`** に変更します。

この `gcp-foundations.xlsx` ファイルが、`make generate` コマンドによって読み込まれる信頼できる唯一の情報源 (SSoT) となります。このファイルは `.gitignore` によりGitの追跡対象外となっているため、テストごとに内容を安全に入れ替えることができます。

詳細なテスト間の遷移手順については、`test_flow_guide.md` も併せて参照してください。

## 3. テストケース一覧

### Phase 0: 初期構築と品質ゲート

IaC基盤として動作を開始するためのセットアップスクリプトと、コードそのものの品質を検証します。

| テストID | テスト項目 | テスト手順 | 期待される結果 | 結果 (OK/NG) | 確認者 | 実施日 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-000a** | `make setup` による構築 | 1. クリーンなGCP組織で `make setup` を実行。<br>2. プロンプトに従いドメインや課金IDを入力。<br>3. 生成された `common.tfvars` に値が正しく出力されていることを確認。 | 管理プロジェクト、tfstate用バケット、SAが作成され、`common.tfvars` と `common.tfbackend` が自動生成されること。 | OK | 光岡 | 2026/05/10 | |
| **TC-000b** | `make check` の精度 | 1. 権限不足のアカウントで `make check` を実行。<br>2. 正しい権限で再度実行。 | 1ではエラーを報告し、2では全項目がパスすること。 | | | | |
| **TC-000c** | コード品質の自動検証 | 1. `make lint`<br>2. `make test` を実行。 | TFLint、ShellCheck、Terraformテスト、Python単体テストがすべてパスすること。 | OK | 光岡 | 2026/05/07 | |
| **TC-000d** | CIパイプラインのブロック機能 | 1. 意図的にフォーマット違反の `.tf` ファイル、または失敗する `.tftest.hcl` をコミットしてPull Requestを作成する。 | GitHub ActionsのLintまたはTestジョブが失敗し、PRのマージがブロックされること。 | OK | 光岡 | 2026/05/07 | |

### Phase 1: 基本リソース生成と整合性検証

本フェーズでは、組織レベルの高度な機能を使わずに、単一のリソースが正しく作成されること、および基本的な入力バリデーションが機能することを確認します。

| テストID | テスト項目 | テスト手順 | 期待される結果 | 結果 (OK/NG) | 確認者 | 実施日 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-001** | 最小構成プロジェクト作成 | 1. `resources`シートに1行（`project`, `organization_id`, `tc001-app`）のみ記述。<br>2. `make generate`<br>3. `make deploy` | エラーなく適用され、GCP組織直下にプロジェクトが1つ作成されること。 | OK | 光岡 | 2026/05/07 | |
| **TC-002** | フォルダ階層の作成 | 1. Excelでフォルダ（`tc002-folder`）とその配下のプロジェクトを定義。<br>2. `make generate`<br>3. `make deploy` | L3レイヤーでフォルダが、L4レイヤーでその配下にプロジェクトが作成されること。 | OK | 光岡 | 2026/05/07 | |
| **TC-003** | 予算と通知の連携 | 1. `resources`で `budget_amount=1000` を設定。<br>2. `make generate`<br>3. `make deploy` | 予算リソースと、監視プロジェクト側に通知チャネルが作成されること。 | OK | 光岡 | 2026/05/07 | |
| **TC-004** | 不正な名称のブロック | 1. `resource_name` に `Upper-Case-Name` や 31文字以上の名前を入力。<br>2. `make generate` | Pythonの `ResourceValidator` がエラーを出力し、生成が停止すること。 | OK | 光岡 | 2026/05/07 | |
| **TC-005** | 入力データのサニタイズ | 1. セル内に全角スペースや改行を含めてデータを入力。<br>2. `make generate`<br>3. `cd terraform/4_projects/xxx && terraform validate` | 生成された `.tf` ファイルが構文エラーにならず、値が正常に処理されること。 | OK | 光岡 | 2026/05/07 | |
| **TC-006** | プロジェクト名重複エラー検知 | 1. `resources`シートに同じ `resource_name` の `project` を2行定義。<br>2. `make generate` | Pythonの `ResourceValidator` が重複エラー（Duplicate resource name）を出力し、生成が停止すること。 | OK | 光岡 | 2026/05/07 | |
| **TC-007** | フォルダとプロジェクト名重複エラー検知 | 1. `resources`シートに同名の `folder` と `project` を定義。<br>2. `make generate` | Pythonの `ResourceValidator` が重複エラーを出力し、生成が停止すること。 | OK | 光岡 | 2026/05/07 | |
| **TC-008** | 未定義親フォルダ参照エラー | 1. `resources`シートで `parent_name` に未定義のフォルダ名を指定。<br>2. `make generate` | Pythonの `ResourceValidator` がエラー（refers to parent 'xxx' which is not defined）を出力すること。 | OK | 光岡 | 2026/05/07 | |
| **TC-009** | 循環参照エラー検知 | 1. `resources`シートで自分自身を `parent_name` に指定（例: Aの親がA）。<br>2. `make generate` | Pythonの `ResourceValidator` がエラー（circular reference）を出力すること。 | OK | 光岡 | 2026/05/07 | |

### Phase 2: ネットワーク統合検証 (Shared VPC)

本フェーズでは、中央管理された共通ネットワーク（Shared VPC）とサービスプロジェクトの紐付けを検証します。

| テストID | テスト項目 | テスト手順 | 期待される結果 | 結果 (OK/NG) | 確認者 | 実施日 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-010** | Shared VPC 統合構築 | 1. `shared_vpc_subnets`を定義。<br>2. `resources`でプロジェクトにサブネット名を紐付け。<br>3. `make deploy` | L1でホストVPCが作成され、L4プロジェクトに `roles/compute.networkUser` 権限が付与されること。 | OK | 光岡 | 2026/05/07 | |
| **TC-011** | CIDR 重複の検知 | 1. `shared_vpc_subnets` で重複またはオーバーラップするIP範囲を定義。<br>2. `make generate` | バリデーションエラー「CIDR overlaps」が表示され、実行が停止すること。 | OK | 光岡 | 2026/05/08 | |
| **TC-012** | 未定義ネットワーク参照 | 1. `resources` の `shared_vpc` 列に実在しないサブネット名を入力。<br>2. `make generate` | 「Refers to undefined shared_vpc subnet」という整合性エラーが報告されること。 | OK | 光岡 | 2026/05/08 | |
| **TC-013** | 機能フラグによる制御 | 1. `common.tfvars` で `enable_shared_vpc=false` に設定。<br>2. Excelにネットワーク定義を残したまま `make deploy` | エラーにならず、Shared VPC関連リソースの作成（`count=0`）が安全にスキップされること。 | OK | 光岡 | 2026/05/08 | |
| **TC-014** | 無効なCIDRフォーマット | 1. `shared_vpc_subnets` に不正なCIDR（例: `10.0.0.300/24`）を入力。<br>2. `make generate` | Pythonの `ResourceValidator` が Invalid CIDR format エラーを出力すること。 | OK | 光岡 | 2026/05/08 | |
| **TC-015** | ホストビットが立っているCIDR | 1. `shared_vpc_subnets` にホストビットが設定されたCIDR（例: `10.0.1.5/24`）を入力。<br>2. `make generate` | Pythonの `ResourceValidator` が Invalid CIDR format エラー（has host bits set）を出力すること。 | OK | 光岡 | 2026/05/08 | |
| **TC-016** | Prod/Dev環境別のホストVPC作成 | 1. `shared_vpc_subnets` に `prod` と `dev` 両方の環境を定義。<br>2. `make generate`<br>3. `make deploy` | L1でprod用とdev用それぞれのVPCとサブネットが正しく作成されること。 | OK | 光岡 | 2026/05/10 | |
| **TC-017** | `enable_vpc_host_projects=false` の挙動 | 1. `common.tfvars` で `enable_vpc_host_projects=false` を設定。<br>2. `make deploy` | ホストVPCリソースが作成されないこと。 | OK | 光岡 | 2026/05/10 | |
| **TC-018** | フォルダへの Shared VPC 設定無視確認 | 1. `resources`シートで `folder` リソースの `shared_vpc` 列に値を入力。<br>2. `make generate` | フォルダに対する Shared VPC 設定が無視され、エラーなく生成されること。 | OK | 光岡 | 2026/05/10 | |
| **TC-019** | `resources`未設定時のサブネット作成 | 1. `shared_vpc_subnets` のみを定義し、`resources` で参照しない。<br>2. `make generate`<br>3. `make deploy` | エラーにならず、ホストVPC側にサブネットのみが作成されること。 | OK | 光岡 | 2026/05/10 | |

### Phase 3: ガバナンス・セキュリティ検証

組織ポリシー、VPC-SC、タグといった統制機能が期待通りに配備されるかを確認します。

| テストID | テスト項目 | テスト手順 | 期待される結果 | 結果 (OK/NG) | 確認者 | 実施日 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-020** | VPC-SC 境界への参加 | 1. `vpc_sc_perimeters`を定義し、プロジェクトを割り当て。<br>2. `make generate`<br>3. `make deploy` | L2でサービス境界が、L4プロジェクトがその境界内のリソースとして登録されること。 | OK | 光岡 | 2026/05/11 | |
| **TC-021** | 組織ポリシーの階層適用 | 1. `org_policies` で組織レベルの制約を `TRUE` に設定。<br>2. `make generate`<br>3. `grep -r "enforce = \"TRUE\"" terraform/2_organization` | 組織レベルの `auto_org_policies.tf` に正しいポリシーが出力されること。 | | | | |
| **TC-022** | 組織タグの動的バインド | 1. `tag_definitions` を定義し、`resources` で指定。<br>2. `make generate`<br>3. `make deploy` | L2でタグキー/値が作成され、プロジェクトに `google_tags_tag_binding` が作成されること。 | | | | |
| **TC-023** | 未定義タグ値のブロック | 1. `resources` に定義外のタグ値（例: `env/stg` だが定義は `prod/dev` のみ）を記述。<br>2. `make generate` | 「Tag value not allowed」エラーとして検知されること。 | | | | |
| **TC-024** | 未定義 VPC-SC ペリメータ参照 | 1. `resources`シートの `vpc_sc` に未定義のペリメータ名を指定。<br>2. `make generate` | Pythonの `ResourceValidator` がエラー（Refers to undefined vpc_sc perimeter）を出力すること。 | | | | |
| **TC-025** | 未定義組織ポリシーターゲット参照 | 1. `org_policies`シートの `target_name` に未定義のリソース名を指定。<br>2. `make generate` | Pythonの `ResourceValidator` がエラー（Target 'xxx' is not defined）を出力すること。 | | | | |
| **TC-026** | 組織ポリシー allow_list 指定 | 1. `org_policies`シートで `enforce` を空欄にし、`allow_list` にカンマ区切りで値を入力。<br>2. `make generate` | 指定した `allow_list` の値がTerraformの `allowed_values` に反映されること。 | | | | |
| **TC-027** | 不正なタグフォーマット | 1. `resources`シートの `org_tags` にスラッシュなし（例: `env:prod`）で入力。<br>2. `make generate` | Pythonの `ResourceValidator` がエラー（Invalid tag format）を出力すること。 | | | | |
| **TC-028** | OPA ポリシー違反検知 (テストコード実行) | 1. 必須ラベル欠落などのモックデータ (`input`) を含む `*_test.rego` を作成。<br>2. ターミナルで `opa test policies/` を実行。 | OPAがポリシー違反を正しく評価し、テストが `PASS`（意図通りに `deny` されたこと）を出力すること。 | | | | |
| **TC-029** | OPA ポリシー構文の検証 | 1. ターミナルで `make opa` を実行。 | 内部で `opa check` が走り、`.rego` ファイルに構文エラーがないことが確認されること。 | | | | |

### Phase 4: 運用（Day 2）およびライフサイクル検証

リソースの変更、特定のレイヤーからの削除、および全環境の撤収が安全に行えるかを確認します。

| テストID | テスト項目 | テスト手順 | 期待される結果 | 結果 (OK/NG) | 確認者 | 実施日 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-030** | リソース名変更の影響 | 1. 構築済みのフォルダ名をExcelで変更。<br>2. `make generate`<br>3. `make deploy` (planを確認) | 既存フォルダの削除(Destroy)と新規フォルダの作成(Create)がプランされることを確認。 | | | | |
| **TC-030b**| 破壊的変更のブロック検証 | 1. `allow_resource_destruction = false` の状態で、`common.tfvars` の `project_id_prefix` を別の文字列（例: `test-prefix`）に変更。<br>2. `make deploy` を実行。 | プロジェクトIDの変更に伴う「再作成（Replace）」が試みられるが、保護機能 (`deletion_policy = "PREVENT"`) によりTerraformまたはGCP側で削除が拒否され、Applyが安全に失敗（ブロック）すること。 | | | | |
| **TC-031** | レイヤー指定削除 (LAYER=4) | 1. `common.tfvars` で `allow_resource_destruction = true` に設定。<br>2. `make deploy` を実行し保護を解除。<br>3. `make destroy LAYER=4` を実行。 | L4（アプリプロジェクト）のみが削除対象となり、L3（フォルダ）以上が維持されること。 | | | | |
| **TC-032** | 破壊保護の連動 | 1. `allow_resource_destruction = true` に設定。<br>2. `make deploy`<br>3. `make destroy` を実行。 | `deletion_protection` が連動して解除され、デッドロックなしにL1〜L4のリソース（管理プロジェクトの器以外）の標準削除が完了すること。 | | | | |
| **TC-033** | 破壊保護有効時の make destroy | 1. `allow_resource_destruction = false` の状態で `make destroy` を実行。 | `destroy_all.sh` スクリプトがエラーを出力し、削除プロセスが開始されないこと。 | | | | |
| **TC-034** | 特定レイヤーの削除 (LAYER=3) | 1. `common.tfvars` で `allow_resource_destruction = true` に設定。<br>2. `make deploy` を実行し保護を解除。<br>3. `make destroy LAYER=3` を実行。 | L4(アプリプロジェクト)とL3(フォルダ)が削除対象となり、L2以上は維持されること。 | | | | |
| **TC-035** | 特定レイヤーの削除 (LAYER=2) | 1. `common.tfvars` で `allow_resource_destruction = true` に設定。<br>2. `make deploy` を実行し保護を解除。<br>3. `make destroy LAYER=2` を実行。 | L4, L3, L2(組織ポリシー等)が削除対象となり、L1は維持されること。 | | | | |
| **TC-036** | 特定レイヤーの削除 (LAYER=1) | 1. `common.tfvars` で `allow_resource_destruction = true` に設定。<br>2. `make deploy` を実行し保護を解除。<br>3. `make destroy LAYER=1` を実行。 | L4〜L1(コアサービス)までが削除対象となること。 | | | | |
| **TC-037** | make destroy ALL の実行 | 1. `allow_resource_destruction = true` に設定。<br>2. `make deploy` および `0_bootstrap` で `apply` を実行し保護を解除。<br>3. `make destroy ALL` を実行。 | 管理プロジェクトの器を含むL1〜L4のすべてのリソースが削除対象となること。 | | | | |
| **TC-038** | 手動変更(ドリフト)の検知 | 1. GCPコンソールからリソースを手動で変更。<br>2. `.github/workflows/drift-detection.yml` と同等のコマンドを実行。 | `terraform plan` で差分が検知されること。 | | | | |
| **TC-039** | make clean による初期化 | 1. ローカルに `.terraform` ディレクトリがある状態で `make clean` を実行。 | 全てのキャッシュディレクトリやロックファイルが削除されること。 | | | | |

### Phase 5: ログ・監視機能検証

ログ集約のフォーマット変換や、アラート定義の整合性を確認します。

| テストID | テスト項目 | テスト手順 | 期待される結果 | 結果 (OK/NG) | 確認者 | 実施日 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-040** | BQ ID サニタイズ | 1. `log_sinks` の `destination_parent` にハイフン入りの名前を指定。<br>2. `make generate`<br>3. `cat terraform/1_core/services/logsink/sinks/auto_global_vars.tf` (確認) | ハイフンがアンダースコア `_` に自動置換され、BigQueryの命名規則に従っていること。 | | | | |
| **TC-041** | ログデータの強制削除 | 1. ログが溜まった状態で `allow_resource_destruction = true` にし `make destroy` | `delete_contents_on_destroy` が機能し、BQデータセットが正常に削除されること。 | | | | |
| **TC-042** | アラート定義の重複検知 | 1. `alert_definitions` に全く同じ `alert_name` を2行作成。<br>2. `make generate` | Python側で重複エラーとして検知され、Terraformのパニックを回避できること。 | | | | |
| **TC-043** | ドキュメント空欄の回避 | 1. `alert_documentation` 列を意図的に空にする。<br>2. `make generate`<br>3. 生成されたコードの `documentation` 属性を確認。 | デフォルトの "No documentation provided." に自動補完されていること。 | | | | |

### Phase 6: 納品と特殊運用

顧客への引き渡しや、トラブル時からの復旧フローなど、特殊な運用シナリオを検証します。

| テストID | テスト項目 | テスト手順 | 期待される結果 | 結果 (OK/NG) | 確認者 | 実施日 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-050** | 課金リンク待ち再開フロー | 1. `core_billing_linked = false` で `make deploy`。<br>2. 課金リンク実施後、`true` にして `make deploy`。 | 初回はAPI有効化がスキップされ、再開後は全サービスが正常にデプロイされること。 | | | | |
| **TC-051** | `make delivery` (納品) | 1. 構築完了後に `make delivery` を実行。 | Git履歴が消去され、`Initial commit` のみの状態で再初期化されること。 | | | | |

## 4. 参照

- `Makefile` による抽象化コマンド
- `ResourceValidator` による整合性チェックロジック
- `destroy_all.sh` によるレイヤー別解体ロジック
