# 組織なしプロジェクトの組織移管 リスク確認 & Terraform 取り込み手順

組織に紐づかない（**No organization**）スタンドアロンのプロジェクトを、ドメイン認証済みの GCP 組織配下へ移管する際の **リスク分析手順** と、移管後に本基盤の **Terraform 管理下へ取り込む手順** をまとめたチェックリストです。

> **本ドキュメントの前提**: 着地先は **組織直下**（`parent_name = organization_id`）を主手順として記載します。フォルダ着地にする場合の差分は各所の「フォルダ着地の場合」を参照してください。

______________________________________________________________________

## 0. 「どちら側で実行するか」の表記ルール

gcloud は手元の 1 つのシェルから実行しますが、**「どちら側か」=「①どの認証 ID（権限）で実行するか」＋「②どのスコープ（`--project` か `--organization`/`--folder`）を対象にするか」** の組み合わせで決まります。本書では各コマンドに以下のタグを付けます。

| タグ | 認証 ID（誰として実行） | 主な対象スコープ |
| :--- | :--- | :--- |
| 🟦 **【移動元】** | 移動元プロジェクトの Owner/Viewer | `--project=$SRC` |
| 🟧 **【移動先】** | 組織管理者（組織レベル権限保持者） | `--organization=$ORG` |
| 🟪 **【両側権限】** | 移動元 `projectMover` **かつ** 移動先 `projectCreator` を持つ ID | 移動操作そのもの |

ID の混線を防ぐため、`gcloud config configurations` で構成を分けて切り替えることを推奨します。

### 変数定義（ローカルシェル・どちらでもない）

```bash
export SRC="source-standalone-proj-id"   # 移動元: 組織なしプロジェクト ID
export ORG="123456789012"                # 移動先: 組織 ID（数値）
export QUARANTINE="quarantine"           # 検疫用フォルダ名（Track B で使用）
# フォルダ着地にする場合のみ:
# export DEST_FOLDER="folders/987654321098"
```

### 認証構成の用意

🟦 **【移動元】**（移動元プロジェクトの Owner でログイン）

```bash
gcloud config configurations create src-admin 2>/dev/null; gcloud config configurations activate src-admin
gcloud auth login
gcloud config set project $SRC
```

🟧 **【移動先】**（組織管理者でログイン）

```bash
gcloud config configurations create org-admin 2>/dev/null; gcloud config configurations activate org-admin
gcloud auth login
```

> 以降、各ブロック冒頭の `gcloud config configurations activate ...` で **どちらの ID か** を切り替えてください。

______________________________________________________________________

## 1. 🟦【移動元】プロジェクトの実態を棚卸し（Cloud Asset Inventory）

```bash
gcloud config configurations activate src-admin    # ← 移動元 ID に切替

# CAI API を移動元プロジェクトで有効化（権限: roles/serviceusage.serviceUsageAdmin on SRC）
gcloud services enable cloudasset.googleapis.com --project=$SRC

# 全リソース棚卸し（権限: roles/cloudasset.viewer on SRC）
gcloud asset search-all-resources --scope=projects/$SRC \
  --format="table(assetType, name, location)" > src_resources.txt

# 全 IAM ポリシー棚卸し（外部ドメイン/個人 Gmail/他プロジェクト SA の混入を探す）
gcloud asset search-all-iam-policies --scope=projects/$SRC > src_iam.txt

# プロジェクト直下の IAM バインディング
gcloud projects get-iam-policy $SRC --format=json > src_iam_policy.json
```

### 「組織ポリシー違反候補」の個別抽出（すべて 🟦移動元 ID・`--project=$SRC`）

```bash
# ★まず Compute API の有効状態を確認する。
#   無効なら VM/ネットワーク/FW は存在しない（= Compute 系チェックは不要）。
#   ⚠️「確認のためだけに」有効化しないこと。有効化すると default VPC と
#      0.0.0.0/0 許可の default-allow-ssh/rdp/icmp が自動生成され、新たな露出になる。
gcloud services list --enabled --project=$SRC \
  --filter="config.name:compute.googleapis.com" --format="value(config.name)"
#   → 何も返らなければ Compute 無効＝以下の Compute 系コマンドはスキップしてよい。

# 外部 IP を持つ VM（compute.vmExternalIpAccess に抵触しうる）
gcloud compute instances list --project=$SRC \
  --format="table(name,zone,networkInterfaces[].accessConfigs[].natIP)"

# OS Login 状態（compute.requireOsLogin で既存 VM の SSH が締め出される恐れ）
gcloud compute project-info describe --project=$SRC \
  --format="value(commonInstanceMetadata.items)"   # enable-oslogin の有無を確認

# 0.0.0.0/0 を許可するファイアウォール
# 注: sourceRanges はリスト型のため --filter でのサーバー側CIDR絞り込みは不可。
#     クライアント側（grep / jq）で抽出する。
gcloud compute firewall-rules list --project=$SRC \
  --format="table(name, direction, network.basename(), sourceRanges.list(), allowed[].map().firewall_rule().list())" \
  | grep -E 'NAME|0\.0\.0\.0/0'
# より正確に（配列に厳密一致する行だけ抽出）:
# gcloud compute firewall-rules list --project=$SRC --format=json \
#   | jq -r '.[] | select((.sourceRanges // []) | index("0.0.0.0/0"))
#            | [.name, .direction, (.sourceRanges|join(",")), (.allowed|tostring)] | @tsv'

# 公開バケット（storage.publicAccessPrevention に抵触しうる）
for b in $(gcloud storage buckets list --project=$SRC --format="value(name)"); do
  echo "== $b =="
  gcloud storage buckets get-iam-policy gs://$b --format="json" \
    | grep -E "allUsers|allAuthenticatedUsers" || echo "  (非公開)"
done

# サービスアカウントキー（iam.disableServiceAccountKeyCreation でローテ破綻の恐れ）
for sa in $(gcloud iam service-accounts list --project=$SRC --format="value(email)"); do
  echo "== $sa =="
  gcloud iam service-accounts keys list --iam-account=$sa --managed-by=user --project=$SRC
done
```

______________________________________________________________________

## 2. 🟧【移動先】組織が課す統制を棚卸し

```bash
gcloud config configurations activate org-admin     # ← 組織 ID に切替

# 組織 ID の確認（権限: roles/resourcemanager.organizationViewer）
gcloud organizations list

# 組織レベルの組織ポリシー一覧（権限: roles/orgpolicy.policyViewer）
gcloud org-policies list --organization=$ORG

# 組織レベル IAM（移動後にこのプロジェクトへ継承される）
gcloud organizations get-iam-policy $ORG --format=json > org_iam.json

# 集約ログシンク（include_children=true なら移動後にログが中央へ流入）
gcloud logging sinks list --organization=$ORG

# VPC-SC 境界（自動では取り込まれないが運用で取り込まれうる）
POLICY=$(gcloud access-context-manager policies list --organization=$ORG --format="value(name)")
gcloud access-context-manager perimeters list --policy=$POLICY
```

> **本リポジトリで管理している場合**: ここで効く組織ポリシーは Excel `org_policies` シート → 生成物 `auto_org_policies.tf`、集約シンクは `1_core/services/logsink` レイヤーが実体です。現在 `common.tfvars` が `enable_org_policies=false` / `enable_vpc_sc=false` / `enable_tags=false` であれば、**移動時に降ってくる強制ポリシーは実質ありません**。ただし将来 `enable_org_policies=true` にした際に何が一斉適用されるかを、Excel `org_policies` シートで事前に確認してください。

______________________________________________________________________

## 3. 差分分析（2 通り）

### Track A — 静的差分（プロジェクトを動かさず、安全）

手順 1 の `src_*.txt` と手順 2 のポリシー一覧を突き合わせ、**各制約に対し移動元が違反していないか** を人手/スクリプトで判定します。移動を伴わないため最も安全ですが、「実際に効くか」は推定です。

### Track B — 実証ドライラン（検疫フォルダ + dry-run、最も正確）★推奨

組織ポリシーの **dryRun（監査のみ・強制しない）** を検疫フォルダに付け、そこへ一時移動して **違反ログを実測** します。

🟧 **【移動先】検疫フォルダ作成 + ドライランポリシー設定**（権限: `roles/resourcemanager.folderAdmin` + `roles/orgpolicy.policyAdmin`）

```bash
gcloud config configurations activate org-admin

# 検疫フォルダ作成
gcloud resource-manager folders create --display-name=$QUARANTINE --organization=$ORG
export QF=$(gcloud resource-manager folders list --organization=$ORG \
  --filter="displayName=$QUARANTINE" --format="value(name)")   # → folders/NNN

# 例: requireOsLogin を「ドライランのみ」で設定（spec 無し = 強制しない）
cat > dryrun_oslogin.yaml <<EOF
name: ${QF}/policies/compute.requireOsLogin
dryRunSpec:
  rules:
  - enforce: true
EOF
gcloud org-policies set-policy dryrun_oslogin.yaml
# 同様に vmExternalIpAccess / publicAccessPrevention 等、検証したい制約を dryRun で追加
```

🟪 **【両側権限】プロジェクトを検疫フォルダへ一時移動**（権限: 移動元 `resourcemanager.projects.move` ＋ 移動先 `resourcemanager.projects.create`）

```bash
gcloud beta projects move $SRC --folder=${QF#folders/}
```

🟧 **【移動先】移動後にドライラン違反を実測**（プロジェクトが組織内に入ったので解析可能）

```bash
# 制約ごとに「どのアセットが違反するか」をプレビュー
gcloud asset analyze-org-policy-governed-assets \
  --scope=organizations/$ORG \
  --constraint=constraints/compute.requireOsLogin

# ドライラン違反ログを確認（強制されていないので壊れない）
gcloud logging read \
  'logName:"dryrun_org_policy" OR protoPayload.metadata.dryRun=true' \
  --organization=$ORG --freshness=1d --limit=50
```

問題がなければ手順 5（本番移動）へ。問題があれば検疫フォルダ内で修正（外部 IP 除去・OS Login 有効化・公開解除・キー整理など）してから進めます。

______________________________________________________________________

## 4. 🟦【移動元】直近ログで「生きている依存」を把握

静的な CAI では見えない動的依存・外部連携を、移動 **前** に把握します。

```bash
gcloud config configurations activate src-admin

# 管理操作ログ（誰が・何を・どの SA で）
gcloud logging read 'logName:"cloudaudit.googleapis.com%2Factivity"' \
  --project=$SRC --freshness=30d --limit=100 \
  --format="table(timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.methodName)"

# データアクセスログ（有効な場合。外部/クロスプロジェクトアクセスの確認）
gcloud logging read 'logName:"cloudaudit.googleapis.com%2Fdata_access"' \
  --project=$SRC --freshness=7d --limit=50
```

______________________________________________________________________

## 5. 本番移動（組織直下へ）

🟪 **【両側権限】組織直下へ移動**

```bash
# ★ 本手順の主シナリオ: 組織直下へ着地
gcloud beta projects move $SRC --organization=$ORG
```

**フォルダ着地の場合**:

```bash
gcloud beta projects move $SRC --folder=${DEST_FOLDER#folders/}
```

🟧 **【移動先】移動結果の検証**

```bash
gcloud config configurations activate org-admin

# 親が組織（または指定フォルダ）に変わったか
gcloud projects describe $SRC --format="value(parent.type, parent.id)"
#  → 組織直下なら type=organization, id=$ORG

# このプロジェクトに“実効”で効いている組織ポリシー
gcloud org-policies list --project=$SRC

# 拒否された操作（本適用後のエラー有無）
gcloud logging read 'protoPayload.status.code!=0 AND severity>=ERROR' \
  --project=$SRC --freshness=1d --limit=50
```

> 検疫フォルダ（Track B）を使った場合は、検証後に検疫用 dryRun ポリシーとフォルダを後片付けしてください。

______________________________________________________________________

## 6. Terraform（本基盤）管理下への取り込み

移動しただけでは Terraform の管理外です。本基盤の L4（Project Factory）で管理するには、**既存プロジェクトを `terraform import` で state に取り込み** ます。

> **組織なしプロジェクトを取り込む典型ケースの完全手順は、まず下記「6-A. adopt モード（推奨・標準手順）」を参照**。命名規則に非準拠な ID でもそのまま取り込めます（6-0 の命名制約は adopt モードで解消されます）。6-0 以降は背景・代替案として残しています。

______________________________________________________________________

### 6-A. adopt モードで取り込む（推奨・標準手順 / 検証済み）

`resources` シートの **`existing_project_id` 列**に既存 ID を書くと、命名規則 `<prefix>-<app_name>` に**非準拠でもそのまま採用**して取り込めます（モジュールが `create_project=false` + `project_id_override` に切替）。**「組織なしプロジェクトを組織へ移動 → 標準管理下に入れる」よくあるケースはこの手順で完結**します。

#### 全体像

```
(組織なしの場合) §5 で組織へ移動  →  Step1 権限  →  Step2 Excel 行  →  Step3 make generate
  →  Step4 init  →  Step5 import  →  Step6 plan（ゲート確認）  →  Step7 apply  →  Step8 検証/運用
```

> ⚠️ 組織なしプロジェクトの「組織への移動」自体が `resourcemanager.allowedImportSources=denyAll`（Google マネージドの secure-by-default）でブロックされることがある。その場合は org admin 権限で `allowedImportSources` を一時 allowAll → `gcloud beta projects move` → 即復元（明示ポリシー削除で既定の denyAll に戻す）。移動は本節の前提（§5）。

#### Step 1. 権限（2系統が必要・ここが最頻ハマりどころ）

1. **TF 実行 SA に対象プロジェクトの `roles/owner`**（プロジェクトの既存 Owner が付与）:
   ```bash
   TF_SA=$(grep terraform_service_account_email terraform/common.tfvars | cut -d'"' -f2)
   gcloud projects add-iam-policy-binding <ACTUAL_PROJECT_ID> \
     --member="serviceAccount:${TF_SA}" --role="roles/owner"
   ```
1. **作業者(operator)自身が SA を借用できること**。本基盤は人間が JSON キーでなく **SA 借用(impersonation)** で操作する設計のため、operator に **`roles/iam.serviceAccountTokenCreator`**（対象 SA、または mgmt プロジェクト）が必要。無いと `iam.serviceAccounts.getAccessToken` 403。SA/mgmt プロジェクト管理者が付与:
   ```bash
   gcloud iam service-accounts add-iam-policy-binding "${TF_SA}" \
     --member="user:<operator>@<domain>" \
     --role="roles/iam.serviceAccountTokenCreator" --project=<MGMT_PROJECT_ID>
   ```
   > 自分自身には付与できない（SA への setIamPolicy が要る）。複数人運用なら**運用グループ（例 `gcp-devops@`）に付与**しておくと個別付与が不要。

#### Step 2. `resources` シートに1行追加

| 列 | 値 | 補足 |
| :--- | :--- | :--- |
| `resource_type` | `project` | |
| `parent_name` | `organization_id` | 組織直下（フォルダ着地ならフォルダ名） |
| `resource_name` | 任意の名前（**4〜30文字**） | ディレクトリ名/表示名/`app`ラベルに使用。**プロジェクト ID には影響しない** |
| `existing_project_id` | `<ACTUAL_PROJECT_ID>` | **adopt のトリガー**（実 ID を採用） |
| `environment` | 任意 | 空欄可（空欄なら `env` ラベルなし）。`shared_vpc` 利用時のみ必須 |
| `owner` | 任意 | 空欄可（空欄なら `owner` ラベルなし）。`@`/`.` 不可 |
| `central_monitoring`/`central_logging` | 方針次第 | 中央監視/ログに載せるなら `TRUE` |
| `budget_amount`/`budget_alert_emails` | 任意 | 設定すると **新規予算を作成**（下記 Step6 の二重化注意） |

#### Step 3. コード生成

```bash
make generate    # → terraform/4_projects/<resource_name>/ が生成（terraform.tfvars に existing_project_id）
```

#### Step 4. init（バックエンド認証の注意）

```bash
cd terraform/4_projects/<resource_name>
terraform init -backend-config="../../common.tfbackend"
```

> ⚠️ **バックエンド(GCS state)の認証は provider の impersonation とは別物**。operator が tfstate バケットに直接権限を持たないと `terraform init` が `storage.objects.list` 403 になる。その場合は **バックエンドにも SA 借用を効かせる**:
>
> ```bash
> export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="${TF_SA}"   # backend と provider の両方に効く
> terraform init -reconfigure -backend-config="../../common.tfbackend"
> ```
>
> （これでも 403 が出るなら Step1-2 の `serviceAccountTokenCreator` 不足）

#### Step 5. import（apply より先に必須）

```bash
terraform import -var-file="../../common.tfvars" \
  module.baseline.module.project.google_project.this <ACTUAL_PROJECT_ID>
```

> import を飛ばして apply/`make deploy` すると、既存 ID で**新規作成**を試みて 409（already exists）。必ず先に import。

#### Step 6. plan（最重要ゲート）

```bash
terraform plan -var-file="../../common.tfvars"
```

- 🛑 **`destroy`/`replace`（特に `google_project`）が出たら apply しない** → ID 不一致か import アドレス誤り。
- ⚠️ **`deletion_policy: PREVENT → DELETE`** が出る場合：`common.tfvars` の `allow_resource_destruction=true`（構築フェーズ既定）のため。**既存（本番）プロジェクトの削除保護を外す**点に留意。維持したいなら `allow_resource_destruction=false` で再 plan（全体共通フラグなので影響に注意）。本番化時に `false` で再ロック。
- ⚠️ **予算の二重化**：`budget_amount` を設定すると `google_billing_budget` を**新規作成**。**手動で作った既存予算は import されない**ので、二重化させたくなければ**事前に手動予算を削除**（Terraform 版のしきい値は 50/90/100%）。
- ✅ 許容差分：`google_project` の **in-place 更新**（`labels` に `app`(+ env/owner/monitoring/logging) 付与、`deletion_policy`）、`google_billing_budget`/`google_monitoring_*` の **create**。
- `billing_account` の**変更が出たら止める**（課金先が `common.tfvars` の `billing_account_id` と不一致。SA では billing 変更不可で apply 失敗する）。

#### Step 7. apply と検証

```bash
terraform apply -var-file="../../common.tfvars"

terraform state list | grep -E "google_project|budget|monitored_project"
gcloud projects describe <ACTUAL_PROJECT_ID> --format="value(parent.id, labels)"
```

#### Step 8. 取り込み後の運用

- 以後は**標準フロー**で管理：Excel 修正 → `make generate` → `make deploy`。このディレクトリは `terraform.tfvars` を持つので **`make deploy` の自動対象**（再 import 不要）。
- **adopt が管理するのは「プロジェクトの箱＋予算/中央監視/ラベル」まで**。既存の **IAM（例: 外部編集者）・有効化済み API は Terraform 管理外**のまま維持される。IAM も IaC 化したいなら `google_project_iam_*` を追加して別途 import。
- 生成された `terraform/4_projects/<resource_name>/` と SSoT(Excel) の変更はコミットしてチーム/CI 管理下に。

______________________________________________________________________

### ⚠️ 6-0.（背景）プロジェクト ID の命名制約 — adopt モードで解消

> **注**: 下記の命名制約は **6-A の adopt モード（`existing_project_id`）で解消されます**。以下は背景理解と、adopt を使わない場合の代替案（B-②/B-③）として残しています。

本基盤の L4 モジュールは、プロジェクト ID を **`<project_id_prefix>-<app_name>` で固定生成** します（[`modules/app-project-baseline/main.tf`](../../terraform/modules/app-project-baseline/main.tf) の `module "project"` → [`modules/project-factory/main.tf`](../../terraform/modules/project-factory/main.tf) の `google_project.this`）。

- **GCP のプロジェクト ID は作成後に変更できません。**
- したがって、移動してきた既存プロジェクトの ID が **`<prefix>-<app_name>` の形に一致していないと、標準フローでは取り込めません**（Terraform は別 ID の「新規作成」を計画してしまう）。
- 例: `project_id_prefix = me-ai` の場合、既存 ID が `me-ai-legacyapp` なら `app_name = legacyapp` として取り込み可能。`old-standalone-123` のような無関係 ID は不可。

| ケース | 対応 |
| :--- | :--- |
| **A. 既存 ID が `<prefix>-<app_name>` に一致** | 下記 6-1 以降の標準 import フローで取り込み（推奨） |
| **B. 一致しない** | ①基盤管理を諦めてそのまま組織配下に置く / ②専用ディレクトリで `google_project` を `project_id` 直書きの一回限り構成として import（標準モジュール外） / ③新規プロジェクトを作りワークロードを移設 |

以降の **6-1〜6-5 はケース A** を前提とします。**ケース B-②**（ID 不一致のまま個別 import）は次の 6-0b を参照。

### 6-0b. ケース B-② 詳細手順（標準モジュール外で `google_project` を直書き import）

既存 ID が `<prefix>-<app_name>` に一致しない（＝標準 L4 フローに乗らない）が、それでも Terraform 管理下に置きたい場合の手順。**専用ディレクトリに単一の `google_project` リソースを実 ID 直書きで用意し、専用 state へ import** する。

#### 方針

- **配置は `terraform/4_projects/` の外**（例: `terraform/4_projects_imported/<name>/`）。
  - 理由: `make generate` は `4_projects/*` の Excel 非定義ディレクトリを「孤立」として `terraform.tfvars` をパージし、`make deploy`(deploy_all.sh) は `4_projects/<name>/terraform.tfvars` を動的検出して自動デプロイする。標準フローの干渉を避けるため外に置き、**このディレクトリは手動 `plan`/`apply` で運用**する。
- 管理対象は **`google_project` 本体のみ**（baseline が行う Shared VPC 接続・VPC-SC バインド・中央監視・タグ付与は含まれない。必要なら後から個別に追加）。

#### 事前準備

```bash
# TF 実行 SA に対象プロジェクトの owner を付与（プロジェクトの既存 Owner で実行）
TF_SA=$(grep terraform_service_account_email terraform/common.tfvars | cut -d'"' -f2)
gcloud projects add-iam-policy-binding <ACTUAL_PROJECT_ID> \
  --member="serviceAccount:${TF_SA}" --role="roles/owner"
```

#### ファイル構成

```
terraform/4_projects_imported/<name>/
├── versions.tf          # 標準テンプレートと同一
├── provider.tf          # 標準テンプレートと同一（SA 借用）
├── backend.tf           # ★ prefix を一意に（例: projects-imported/<name>）
├── variables.tf         # 使う変数のみ宣言
├── auto_global_vars.tf  # common.tfvars の未使用キーを吸収（warning 抑制）
└── main.tf              # ★ google_project を実 ID 直書き
```

`main.tf` の要点:

```hcl
data "google_organization" "org" {
  domain = var.organization_domain
}

resource "google_project" "this" {
  project_id = "<ACTUAL_PROJECT_ID>"   # 実 ID をそのまま（変更不可）
  name       = "<EXISTING_DISPLAY_NAME>"
  org_id     = data.google_organization.org.org_id   # 組織直下の場合
  labels     = {}                                     # 実態に合わせる

  deletion_policy = "PREVENT"   # 誤削除防止

  lifecycle {
    prevent_destroy = true                 # destroy/replace をブロック
    ignore_changes  = [
      auto_create_network,                 # 作成時専用属性。import 後の差分を無視
      billing_account,                     # 課金は別管理（誤って解除/切替しない）
    ]
  }
}
```

> **課金アカウントの注意**: `billing_account` を **config に書かず ignore_changes** にすると、import 後も現状リンクを維持し TF は触らない。課金を共通アカウントへ移行する作業を別途行う場合に安全。TF で課金も管理したくなったら `billing_account = var.billing_account_id` を明示し、`ignore_changes` から外す。

#### import → 検証 → 適用

```bash
cd terraform/4_projects_imported/<name>
terraform init -backend-config=../../common.tfbackend
terraform import -var-file=../../common.tfvars google_project.this <ACTUAL_PROJECT_ID>
terraform plan  -var-file=../../common.tfvars   # ★ destroy/replace が無いことを確認
terraform apply -var-file=../../common.tfvars
```

- import アドレスは **`google_project.this`**（モジュール外なのでフルパス不要。標準フローの `module.baseline.module.project.google_project.this` とは異なる）。
- `plan` で **`destroy`/`replace` が出たら適用しない**（ID 不一致 or import 誤り）。`prevent_destroy=true` が保険として apply をブロックする。
- 許容差分は `name`/`labels`/`deletion_policy` の in-place のみ。

#### 運用・注意

- `make generate`/`make deploy` の対象外。変更時はこのディレクトリで手動 `plan`/`apply`。
- CI の `validate` ジョブは対象に含まれる（問題なし）。OPA のラベル必須チェックは標準 plan フロー前提のため、ラベルを使うなら `main.tf` に明示する。
- 将来 B-③（標準化＝新 ID で作り直して移設）へ切り替える余地は残る。

### 6-0c. 取り込み済みプロジェクトへの「管理パリティ」付与（アプローチA：現措置）

B-② で `google_project` 単体を取り込んだ後、resources シート由来の標準プロジェクトと**同等の管理**（中央監視・ログ集約・組織タグ・Shared VPC・VPC-SC）を付与する手順。標準では `app-project-baseline` が内部で行うが、ID 非準拠のため**同等のリソースを B-② 専用ディレクトリに手書きで足す**（＝アプローチA）。本質的な仕組み化は後述の B（[design/todo.md](../design/todo.md) の adopt モード）で行う。

> **位置づけ**: A は「1件限りの現実解」。`make generate`/`make deploy` の対象外＝**手動保守・ドリフト注意**。各レイヤーの output は `terraform_remote_state` で跨いで参照する（**prefix は各レイヤーの `backend.tf` で確認**）。

#### 機能別の付与手順・手間・リスク

| 機能 | 付与方法 | 手間 | リスク |
|:--|:--|:--:|:--|
| **ログ集約** | **不要**（組織配下にいるだけで `include_children` 集約シンクの対象） | なし | 低（ログ量・課金微増） |
| **中央モニタリング** | `google_monitoring_monitored_project` を追加 | 小 | 低 |
| **組織タグ** | 2_organization の `tag_value_ids` を参照し `google_tags_tag_binding` | 小〜中 | 低（非破壊） |
| **予算/ラベル** | `labels` 明示・`google_billing_budget`（課金統一後） | 小 | 低 |
| **Shared VPC** | `google_compute_shared_vpc_service_project` ＋ サブネットIAM | 大 | **高**（既存NW移行＝接続断の恐れ） |
| **VPC-SC** | 2_organization の `service_perimeter_ids` を参照し境界へ追加 | 中 | **高**（境界の二重管理競合／既存連携の遮断） |

#### 実装スニペット（B-② ディレクトリ `terraform/4_projects_imported/<name>/` に追記）

```hcl
# --- 中央モニタリング（低リスク・推奨） ---
resource "google_monitoring_monitored_project" "this" {
  metrics_scope = "<monitoring-project-id>"          # スコープ親（monitoring プロジェクト）
  name          = "projects/${google_project.this.number}"
}

# --- 組織タグ（低リスク） ---
data "terraform_remote_state" "organization" {
  backend = "gcs"
  config  = { bucket = var.gcs_backend_bucket, prefix = "<2_organization の prefix>" }
}
resource "google_tags_tag_binding" "this" {
  for_each  = toset(["<tag_key>/<tag_value>"])       # 付与するタグ
  parent    = "//cloudresourcemanager.googleapis.com/projects/${google_project.this.number}"
  tag_value = data.terraform_remote_state.organization.outputs.tag_value_ids[each.key]
}
```

> **Shared VPC / VPC-SC は本ディレクトリでも技術的に可能**だが、「IaC に足す」こと自体より**実環境を共有VPC/境界へ入れ替える運用変更**が本体でありリスクの主因。投入する場合は DryRun・段階移行で必ず影響確認すること。VPC-SC は 2_organization 側 perimeter の `lifecycle ignore_changes` と**二重管理にならない**よう、どちらの state で resource を持つかを先に決める。

#### 手順

```bash
cd terraform/4_projects_imported/<name>
# 1) 付与したいリソースを main.tf に追記（上記スニペット）
# 2) 既に実在する関連リソース（例: 既存の monitored_project）があれば個別 import
terraform plan  -var-file=../../common.tfvars   # 破壊的差分が無いこと
terraform apply -var-file=../../common.tfvars
```

### 6-1. 🟦【移動先プロジェクト Owner】Terraform 実行 SA に権限付与

組織レベルのロールだけでは「既存プロジェクトの管理」はできません。移動後、Terraform 実行 SA（`common.tfvars` の `terraform_service_account_email`）にプロジェクトレベルの権限を付与します。プロジェクトの既存 Owner（= `src-admin`）で実行します。

```bash
gcloud config configurations activate src-admin      # 移動後もこのプロジェクトの Owner

TF_SA=$(grep terraform_service_account_email terraform/common.tfvars | cut -d'"' -f2)
gcloud projects add-iam-policy-binding $SRC \
  --member="serviceAccount:${TF_SA}" --role="roles/owner"
```

### 6-2. SSoT（Excel）へ行を追加 → コード生成

`gcp-foundations.xlsx` の `resources` シートに、移動したプロジェクトの行を追加します（**組織直下着地のため `parent_name = organization_id`**）。

| カラム | 設定値（例） |
| :--- | :--- |
| `resource_type` | `project` |
| `parent_name` | `organization_id`（組織直下）／フォルダ着地なら当該フォルダ名 |
| `resource_name` | 既存 ID から prefix を除いた `app_name`（例: 既存 `me-ai-legacyapp` → `legacyapp`） |
| その他（`shared_vpc` / `vpc_sc` / `central_*` など） | 必要に応じて |

```bash
# ローカル（リポジトリルート）
make generate
# → terraform/4_projects/<app_name>/ に terraform.tfvars / backend.tf / *.tf が生成される
```

### 6-3. 既存プロジェクトを Terraform state へ import

```bash
cd terraform/4_projects/<app_name>

# backend 初期化（共通バックエンド）
terraform init -backend-config="../../common.tfbackend"

# google_project を import（import アドレスは入れ子モジュールのフルパス）
#   terraform.tfvars は自動ロード、共通変数のみ -var-file で渡す
terraform import -var-file="../../common.tfvars" \
  module.baseline.module.project.google_project.this $SRC
```

> import ID は **既存プロジェクト ID**（`$SRC`）をそのまま指定します。

### 6-4. 差分確認 → 適用

```bash
terraform plan -var-file="../../common.tfvars"
```

import 直後の `plan` では、以下のような **in-place 更新** が出るのが正常です。内容を確認し、想定どおりであることを確認してください。

- `name`（表示名）→ `<app_name>-<environment>` に更新
- `labels` → `env` / `owner` / `app`（+ `monitoring` / `logging`）が付与
- `deletion_policy` → `PREVENT`（`allow_resource_destruction=false` の既定時）
- `billing_account` → `common.tfvars` の `billing_account_id`（既存リンクと同一なら差分なし）

> **破壊的差分（`destroy`/`replace`）が出た場合は適用しないでください。** ほぼ確実に「ID 不一致（ケース B）」か import アドレス誤りです。6-0 を再確認してください。

問題なければ適用します（個別 apply、または基盤全体の `make deploy` でも可。`make deploy` は `terraform.tfvars` が存在する `4_projects/*` を自動検出します）。

```bash
terraform apply -var-file="../../common.tfvars"
# あるいはリポジトリルートで:  make deploy
```

### 6-5. 取り込み後の確認

```bash
terraform state list | grep google_project        # state に存在するか
gcloud projects describe $SRC \
  --format="value(parent.type, parent.id, labels)" # 親・ラベル反映の確認
```

______________________________________________________________________

## ⚠️ 重要な前提・注意

- **不可逆性**: 一度組織に入れたプロジェクトを「組織なし（No organization）」へ戻すのは原則自己解決不可（要 Google サポート）。実質ほぼ片道のため、Track B で十分検証してから本番移動すること。
- **移動操作の権限**: 移動だけは「移動元と移動先の両方の権限」を同一 ID が持つ必要がある。無い場合は一時的に移動元へ `roles/resourcemanager.projectMover`、移動先（組織/フォルダ）へ `roles/resourcemanager.projectCreator` を付与する。
- **OS Login の罠**: `compute.requireOsLogin` を強制すると、メタデータ SSH 鍵で入っていた既存 VM から締め出される恐れ。手順 1 の OS Login 確認 →（必要なら）`roles/compute.osLogin` 付与を先に行う。
- **🚨 デフォルトサービスアカウントを削除しない（実障害事例あり）**: 移管準備の「不要 SA 整理」で、**Compute Engine デフォルト SA（`<PROJECT_NUMBER>-compute@developer.gserviceaccount.com`）や App Engine デフォルト SA（`<PROJECT_ID>@appspot.gserviceaccount.com`）を削除してはならない。**
  - これらは Compute API 等の有効化時に**自動作成**されるが、「自動作成された＝未使用・使い捨て可能」ではない。**Vertex AI（カスタム訓練・パイプライン・バッチ/オンライン予測・Workbench）・Cloud Functions・Cloud Run・Dataflow 等が、カスタム SA を明示しない限りこれを"既定の実行 ID"として使う。**
  - 実例: 移管準備中に Compute デフォルト SA を削除したところ、**Vertex AI が停止**（ワークロードのランタイム ID 喪失）。IAM 監査ログ上は `roles/editor` のメンバーが `deleted:serviceAccount:...?uid=...` と表示され、Google 内部の `service-agent-manager` による `SetIamPolicy` で `code:10 ABORTED`（concurrent policy changes）が多発した。なお `code:10` 自体は一時的な競合で無害、停止の主因は SA 削除そのもの。
  - **削除可否は「作成時刻」ではなく「使用状況」で判断する**: 削除前に、その SA を VM・Vertex ジョブ・パイプライン・エンドポイント等が**ランタイムに指定していないか**を確認すること（`gcloud asset search-all-resources` や各サービスのジョブ定義）。
  - **復旧**: 削除から **30 日以内**なら unique ID で復元可能。
    ```bash
    gcloud iam service-accounts undelete <UNIQUE_ID> --project=$SRC
    # UNIQUE_ID は監査ログの uid=... や `gcloud iam service-accounts list --show-deleted` で取得
    ```
  - 復元後は SA の存在（`describe`）・`roles/editor` 等の権限復活・対象サービス（Vertex AI 等）のエラー解消を確認する。
- **ログ流入コスト**: 集約シンク（`include_children`）により、移動後は中央 BigQuery/GCS のデータ量・課金が増える。
- **課金リンク**: 本基盤では billing の紐付けは人間（請求管理者）が手動で行う設計（SA では `gcloud billing projects link` が GCP 仕様で不可）。既存プロジェクトの課金先が `billing_account_id` と異なる場合は事前に整合させる。
- **プロジェクト ID は変更不可**: 6-0 の命名制約を必ず満たすこと。

______________________________________________________________________

## 関連ドキュメント

- [プロジェクトのライフサイクル管理](./project_lifecycle.md)
- [環境の一括解体・クリーンアップガイド](./environment_destruction.md)
- [データディクショナリ](../design/data-dictionary.md)（`resources` シート / `shared_vpc_env` 等）
- [アーキテクチャ設計書](../design/architecture.md)
