# 設計改善履歴: 管理プロジェクトの階層化

## ✅ 対応済み: 案B（Bootstrap L0 の役割拡張）を採用

組織直下にフラットに並んでいた管理プロジェクト（`*-logsink`, `*-monitoring`, `*-vpc-prod/dev`）を、専用フォルダに整理するため **案B** を実装した。
※ `*-tfstate-xxxx` は意図的に組織直下に残す（理由は下記）。

### 実装結果

```text
GCP Organization
├── *-tfstate-xxxx               ← 組織直下に残す（誤削除防止・権限循環回避）
├── admin/                       ← L0で先行作成
│   ├── *-logsink                ← Terraform で自動配置
│   └── *-monitoring             ← Terraform で自動配置
├── network/                     ← L0で先行作成
│   ├── *-vpc-prod               ← Terraform で自動配置
│   └── *-vpc-dev                ← Terraform で自動配置
└── [Excelで定義したビジネス用フォルダ]
    ├── production/
    ├── staging/
    └── development/
```

### tfstate プロジェクトを組織直下に残す理由

| 観点 | 説明 |
|:---|:---|
| **誤削除耐性** | `admin` フォルダを誤って削除しても tfstate プロジェクトは無傷で残る。Tier 0 メタリソースとして最も上位に保持 |
| **権限循環の回避** | Terraform SA は自身が住むプロジェクトの移動・削除権限を持たない設計。組織直下なら SA 操作対象外で安定 |
| **緊急時の独立性** | 全レイヤーが壊れても tfstate だけは残るため、人間オペレータがゼロから復旧可能 |

Google の Enterprise Foundation Blueprint では bootstrap フォルダ配下が推奨されているが、本リポジトリの「安全性最優先 + SA自動化」の設計思想を踏まえると、組織直下が合理的。

### 主要な変更点

- `terraform/0_bootstrap/` で `google_folder.admin` / `google_folder.network` を作成
- 各レイヤーは `data.terraform_remote_state.bootstrap` 経由でフォルダIDを参照
- vpc-host が L3（フォルダ）を待つ必要がなくなり、L1 base 内で完結
- `deploy_all.sh` のデプロイ順序を簡素化（vpc-host が L3 後に再実行される歪な順序を解消）

### 既存環境への適用手順

新規環境では `make setup` 一発で完結する。既存環境の場合は以下が追加で必要：

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)

# 1. 0_bootstrap を apply してフォルダ作成
cd "${REPO_ROOT}/terraform/0_bootstrap"
terraform init -backend-config="${REPO_ROOT}/terraform/common.tfbackend" -reconfigure
terraform apply \
  -var-file="${REPO_ROOT}/terraform/common.tfvars" \
  -var-file="terraform.tfvars"

# 2. プロジェクトをフォルダに移動
#    ※ tfstate プロジェクトは意図的に組織直下に残すため、移動対象に含めない
ADMIN_FOLDER=$(terraform output -raw admin_folder_id)
NETWORK_FOLDER=$(terraform output -raw network_folder_id)

# 移行するプロジェクトのIDを変数に設定（適宜書き換えてください）
export LOGSINK_PROJECT=""
export MONITORING_PROJECT=""
export VPC_PROD_PROJECT=""
export VPC_DEV_PROJECT=""

export SA_EMAIL="terraform-org-manager@<project_id>.iam.gserviceaccount.com"

gcloud beta projects move ${LOGSINK_PROJECT}    --folder=${ADMIN_FOLDER#folders/} --impersonate-service-account=${SA_EMAIL} --quiet
gcloud beta projects move ${MONITORING_PROJECT} --folder=${ADMIN_FOLDER#folders/} --impersonate-service-account=${SA_EMAIL} --quiet
gcloud beta projects move ${VPC_PROD_PROJECT}   --folder=${NETWORK_FOLDER#folders/} --impersonate-service-account=${SA_EMAIL} --quiet
gcloud beta projects move ${VPC_DEV_PROJECT}    --folder=${NETWORK_FOLDER#folders/} --impersonate-service-account=${SA_EMAIL} --quiet

# 3. Terraform state を実態に合わせる（差分は自動吸収される）
for dir in 1_core/base/logsink 1_core/base/monitoring 1_core/base/vpc-host; do
  cd "${REPO_ROOT}/terraform/${dir}"
  terraform init -backend-config="${REPO_ROOT}/terraform/common.tfbackend" -reconfigure
  terraform apply -var-file="${REPO_ROOT}/terraform/common.tfvars"
done

# あるいは、Step 3 は `make deploy` でも代用可能
```

______________________________________________________________________

## 今後の検討事項

### 優先度サマリー

| 提案 | 効果 | 実装コスト | 優先度 |
|:---|:---:|:---:|:---:|
| `make cost`（Infracost 統合） | 高 | 低 | ⭐⭐⭐ |
| `make security`（Checkov 統合） | 高 | 低 | ⭐⭐⭐ |
| アーキテクチャ図自動生成 | 高 | 中 | ⭐⭐ |
| SCC（Security Command Center）連携 | 中 | 中 | ⭐⭐ |
| 既存プロジェクト採用(adopt)モード | 高 | 中〜高 | ⭐⭐ |
| ファイアウォールルール管理 | 中 | 高 | ⭐ |
| Slack/Teams デプロイ通知 | 中 | 低 | ⭐⭐ |
| `deploy_all.sh` デッドコード修正 | 低 | 低 | ⭐⭐⭐ |

______________________________________________________________________

### 🆕 新機能

#### 1. `make cost` — デプロイ前コスト見積もり（Infracost 統合）

`make generate` の直後に月額見積もりを CLI で表示する。`make lint` と同様に CI ゲートに組み込むことで、意図しないコスト増加をプルリクエスト段階で検知できる。

- ツール: [Infracost](https://www.infracost.io/)
- 実装イメージ:
  ```makefile
  cost:
      infracost breakdown --path terraform/ --format table
  ```
- GitHub Actions の PR コメントに差分コストを自動投稿する拡張も容易。

#### 2. `make security` — Terraform セキュリティスキャン（Checkov 統合）

生成された Terraform コードに対して CIS GCP ベンチマークおよび独自ポリシーの違反を検出する。既存の OPA（`make opa`）が Excel 入力バリデーションを担うのに対し、Checkov は生成後の Terraform コードそのものをスキャンする位置づけ。

- ツール: [Checkov](https://www.checkov.io/)
- 実装イメージ:
  ```makefile
  security:
      checkov -d terraform/ --framework terraform
  ```

#### 3. `make diagram` — SSoT からアーキテクチャ図を自動生成

`resources` シートのフォルダ/プロジェクト階層を読み込み、Mermaid 記法または Draw.io 形式でアーキテクチャ図を出力する。`generate_resources.py` と同様の Excel 読み込みロジックを流用できるため、`generate_template.py` などの既存スクリプトと整合しやすい。

- 出力先候補: `docs/design/architecture_generated.md`（Mermaid）
- ドキュメントとインフラの乖離をゼロにできる。

#### 4. Slack / Teams デプロイ通知

CI（GitHub Actions）の `main-apply.yml` はあるが、手動 `make deploy` / `make destroy` の完了・失敗がチームに通知されない。`deploy_all.sh` の末尾に webhook 呼び出しを追加することで、オンコールチームへのリアルタイム通知が実現できる。

#### 5. SCC（Security Command Center）連携

Security Command Center の Findings を BigQuery に自動エクスポートし、既存の `asset_inventory` データセットに `v_scc_findings` ビューを追加する。`v_iam_policy` との結合で「誰が何にアクセスでき、どのセキュリティ警告があるか」を一元照会できる。

#### 6. ファイアウォールルール管理

Shared VPC のサブネットは SSoT で管理されているが、ファイアウォールルールは対象外。`shared_vpc_subnets` シートに隣接する `firewall_rules` シートを追加することで、ネットワーク管理を一元化できる。実装コストが高いため、他の提案が落ち着いてから着手する。

#### 9. 既存プロジェクト採用(adopt)モード — 非準拠IDの既存プロジェクトを標準管理下に

> **✅ 実装済み（2026-06-08 / Phase 1 + Phase 2）**:
> - `modules/project-factory`: `create_project`(bool, 既定 true) / `project_id_override`(string) を追加。`effective_project_id = create_project ? project_id : (project_id_override != "" ? project_id_override : project_id)`。**既定では従来どおり** var.project_id を使用＝後方互換（回帰テスト `adopt.tftest.hcl` で検証、`make test` 緑）。
> - `modules/app-project-baseline`: `existing_project_id` を追加し、空でなければ `create_project=false` + `project_id_override` を project-factory へ透過。
> - `4_projects/template`: `existing_project_id` 変数と baseline への透過を追加（生成プロジェクトに引き継がれる）。
> - `generate_resources.py`: `resources` シートに `existing_project_id` 列を追加（ヘッダーは実ファイルから読むため既存 xlsx 非破壊）。`terraform.tfvars` に出力。採用行は **ID形式チェック＋ existing_project_id の重複禁止** をバリデーション。
> - **未対応（Terraform 仕様上の制約）**: `lifecycle.ignore_changes` は変数で動的化できないため固定のまま。採用 import 直後の属性差分（name/labels/deletion_policy）は **import → plan レビュー → apply** で吸収する運用（[migration/project_migration_risk_check.md](../migration/project_migration_risk_check.md) 6-3〜6-4）。
> - **使い方**: `resources` シートに `existing_project_id` を記入 → `make generate` → 一度だけ `terraform import module.baseline.module.project.google_project.this <ID>` → `plan`（destroy/replace が無いこと）→ `apply`。以降は標準フローで管理。

**背景・課題**: 組織へ移管してきた既存プロジェクトのうち、project_id が基盤命名規則 `<project_id_prefix>-<app_name>` に一致しないものは、resources シート（SSoT）に載せても「別IDで新規作成」を計画してしまい、標準フローで取り込めない（[migration/project_migration_risk_check.md](../migration/project_migration_risk_check.md) の 6-0 ケースB）。現状の回避策は **B-②（専用ディレクトリで `google_project` を直書き import し、管理リソースを手書きで足す＝アプローチA）** だが、`make generate`/`make deploy` の対象外で**ドリフトしやすく・都度配線が必要**。

**目的**: 既存プロジェクトを **`app-project-baseline` と同一ロジックで管理**（中央監視・ログ・Shared VPC・VPC-SC・タグ・予算）できるようにし、最終的に **SSoT(Excel) 駆動**まで到達する。

**設計案（段階導入）**:

1. **モジュール側に「採用モード」を追加**
   - `modules/project-factory`: `create_project`（bool, default true）と `project_id_override`（string, default ""）を追加。
     - `create_project=false` の場合、`google_project` を新規作成扱いにせず、`project_id = coalesce(project_id_override, "<prefix>-<app_name>")` で**既存IDを採用**（実体は `terraform import` で state に取り込む）。
   - `modules/app-project-baseline`: 上記フラグを透過。下流の監視/VPC/VPC-SC/タグ各リソースは元々 `project_id`/`project_number` を入力に取るため、**採用したIDをそのまま渡せば変更不要**。
   - 既存属性（`deletion_policy`/`billing_account`/`labels`）は import 後に差分が出ないよう、採用モードでは `lifecycle.ignore_changes` を選択可能にする（移行期間の課金切替などに対応）。

2. **SSoT(Excel) 拡張（任意・最終形）**
   - `resources` シートに `existing_project_id` 列を追加。値があれば `generate_resources.py` が「採用モード」のディレクトリ（`create_project=false` + `project_id_override`）を生成。
   - 生成後は人間が一度だけ `terraform import` を実行（ID変更不可のため import は不可避）。以降は標準フロー（`make generate`/`make deploy`）で管理。
   - バリデーション追加: `existing_project_id` の形式チェック、通常生成IDとの二重定義禁止。

3. **移行手順（既存プロジェクト1件あたり）**
   - SA に対象プロジェクトの `roles/owner` 付与 → `make generate` → `terraform import module.baseline.module.project.google_project.this <ID>` → `plan`（destroy/replace が無いこと）→ `apply`。

**手間（見積もり）**: project-factory/baseline のフラグ実装＋tftest＝中。Excel列＋generate対応＝中。合計**中〜高**。

**リスク**:
- **共有モジュール改修は全プロジェクトに波及**。`create_project` 分岐の既定値を誤ると新規作成フローを壊す → tftest で「従来どおり新規作成される」回帰テストを必須化。
- import 時の属性差分（billing/labels/deletion_policy）の吸収設計を誤ると、初回 apply で意図しない変更。
- Shared VPC/VPC-SC を採用プロジェクトに適用するのは「IaC配線」ではなく**実環境の移行**であり、本機能とは別のリスク（接続断・締め出し）。adopt モードは「管理下に置く」までを担い、ネットワーク/境界投入は段階適用で別途判断する。

**現状の位置づけ**: 当面は **アプローチA（B-②手書き）** で個別対応（[migration/project_migration_risk_check.md](../migration/project_migration_risk_check.md) 6-0b・6-0c）。本 adopt モードは「非準拠IDの取り込みが今後も継続する」と判断した段階で着手する。

______________________________________________________________________

### 🔧 既存コードの改善

#### 7. `deploy_all.sh` の安全確認プロンプトがデッドコードになっている問題

`deploy_all.sh` の 7 行目で `export TF_IN_AUTOMATION="true"` を設定しているため、63 行目の安全確認プロンプト（`allow_resource_destruction=true` 時の y/N 確認）は条件式 `"$TF_IN_AUTOMATION" != "true"` が常に偽となり、**絶対に実行されない**。

```bash
# 7行目（常にtrue）
export TF_IN_AUTOMATION="true"

# 63行目（TF_IN_AUTOMATION が常に true なので到達不能）
if [[ "$ALLOW_DESTROY" == "true" && ... && "$TF_IN_AUTOMATION" != "true" ]]; then
    echo "⚠️ WARNING: allow_resource_destruction is set to true..."
fi
```

対応方針（要議論）:

- **案A**: 条件から `"$TF_IN_AUTOMATION" != "true"` を削除し、手動実行時にも警告を表示する
- **案B**: デッドコードであることをコメントで明示し、意図的な設計として残す

#### 8. `owner` バリデーションの柔軟化（任意）

現在の正規表現 `^[a-z0-9_-]{1,63}$` はGCPラベルとして正しいが、Google Group のエイリアス（例: `infra-team`）が入力値として多いため現状でも実用上の問題は少ない。さらに厳密にする場合は `gcloud identity groups describe` で実在確認するオプションを `make check` に組み込む方法がある。ただし API 呼び出しコストが増えるため優先度は低い。
