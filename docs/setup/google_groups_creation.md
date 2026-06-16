# Google グループの作成ガイド (Cloud セットアップの活用)

本リポジトリでは、GCP 組織の管理に必要な Google グループを、Google Cloud コンソールの「Cloud セットアップ」機能を利用して作成することを推奨しています。

## 1. なぜ「Cloud セットアップ」を使うのか？ (設計思想)

通常、Google グループを Terraform で作成するには、実行環境（サービスアカウント）に Google Workspace の特権管理者権限（ドメイン全体の委任など）を付与する必要があります。これはセキュリティ上のハードルが非常に高く、承認に時間がかかることが一般的です。

「Cloud セットアップ」をグループ作成機として活用することで、以下のメリットが得られます。

- **権限の分離**: Google Workspace の操作（グループ作成）は顧客の管理者が行い、GCP リソースの操作（権限付与）は Terraform が行うという明確な役割分担が可能です。
- **標準化**: Google が推奨する標準的なグループ名（`gcp-organization-admins` 等）で確実に作成できます。
- **柔軟性**: Cloud セットアップの「概念実証モード（2グループ）」と「本番環境モード（9グループ）」の両方に対応しており、組織の規模に合わせて選択できます。

## 2. 実践的な「コツ」：どこまで進めるか

Cloud セットアップは最後まで進める必要はありません。**「グループが作成された直後」で止める**のが、Terraform と競合させないためのポイントです。

### 手順

1. **顧客による操作**: 組織レベルの権限を持つユーザーで GCP コンソールにログインし、「Cloud セットアップ」（セットアップ チェックリスト）を開きます。
1. **モードの選択**:
   - **導入スピード優先の場合**: 「概念実証（PoC）モード」を選択します（2つのグループが作成されます）。
   - **最初から厳格に運用する場合**: 「本番環境モード」を選択します（9つのグループが作成されます）。
1. **グループの作成**: 画面の指示に従い、Google グループを作成するステップまで進めます。
1. **【重要】ここで停止**: グループの作成が完了したことを確認したら、**IAM 権限を付与するステップには進まず、コンソールを閉じます。**
   - 以降の権限付与（IAM）は、本リポジトリの Terraform によってプログラマブルに、かつ構成変更が追跡可能な状態で管理されます。

## 3. Terraform との連携

作成されたグループの構成に合わせて、`make setup` 実行時に `Simplified Groups` オプションを選択してください。

- **PoC モードで作成した場合**: `Simplified Groups = true` (2グループ構成)
- **本番モードで作成した場合**: `Simplified Groups = false` (9グループ構成)

これにより、Cloud セットアップで作成された「箱（グループ）」に対して、本リポジトリが定義する「中身（権限）」を自動で流し込むことができます。

## 4. 付与されるロール（権限の「中身」）

ロール定義は `terraform/2_organization/main.tf` の `locals.raw_roles` にあります。組織レベル（`google_organization_iam_member`）への付与は **`enable_group_iam = true` のときのみ**行われます（`false` の場合はグループへのバインドを一切作成しません）。

### 本番モード（`enable_simplified_admin_groups = false`）

9 グループそれぞれに `raw_roles` の定義どおり付与します（職務分掌：組織管理 / 請求 / ネットワーク / ハイブリッド接続 / ログ・監視（管理・閲覧）/ セキュリティ / 開発者 / DevOps）。

### 簡略モード（`enable_simplified_admin_groups = true`）

2 グループに集約します。`gcp-billing-admins` は請求系 2 ロール、`gcp-organization-admins` は「**請求以外の全ロールの和集合**」です。

#### 直近の変更：冗長ロールの掃除（29 → 18 ロール）

和集合を素朴に集約すると、**上位の admin ロールや基本ロール `roles/viewer` に包含される冗長ロール**を含んでしまっていました（付与しても権限は増えず監査ノイズになるだけ）。`local.simplified_redundant_roles`（denylist）で次の **11 ロールを除外**し、`gcp-organization-admins` を **29 → 18 ロール**に整理しました。`raw_roles`（本番モード）は不変です。

| 除外した冗長ロール | 包含元（保持されるロール） |
|---|---|
| `logging.viewer` / `logging.configWriter` / `logging.privateLogViewer` | `logging.admin` |
| `monitoring.viewer` | `monitoring.admin` |
| `resourcemanager.folderViewer` / `resourcemanager.folderIamAdmin` | `resourcemanager.folderAdmin` |
| `resourcemanager.organizationViewer` | `resourcemanager.organizationAdmin` |
| `iam.organizationRoleViewer` | `iam.organizationRoleAdmin` |
| `browser` / `compute.viewer` / `container.viewer` | 基本ロール `roles/viewer` |

> ⚠️ **`iam.securityReviewer` は意図的に残置**しています。横断的な `getIamPolicy`（多サービスの IAM ポリシー読み取り）を持ち、`iam.securityAdmin` にも基本 `roles/viewer` にも包含されないため除外すると権限が欠けます（“包含されているように見えて実は包含されない”罠）。

#### 最終的に付与されるロール一覧（簡略モード）

掃除後に実際に付与されるロールは以下のとおり。

**`gcp-organization-admins`（18 ロール）**

| # | ロール | 区分 |
|---|---|---|
| 1 | `roles/resourcemanager.organizationAdmin` | 組織管理 |
| 2 | `roles/resourcemanager.folderAdmin` | フォルダ管理 |
| 3 | `roles/resourcemanager.projectCreator` | プロジェクト作成 |
| 4 | `roles/orgpolicy.policyAdmin` | 組織ポリシー |
| 5 | `roles/iam.organizationRoleAdmin` | カスタムロール管理 |
| 6 | `roles/iam.securityAdmin` | IAM 管理 |
| 7 | `roles/iam.securityReviewer` | IAM 横断 read（残置）|
| 8 | `roles/iam.serviceAccountCreator` | SA 作成 |
| 9 | `roles/securitycenter.admin` | SCC 管理 |
| 10 | `roles/cloudkms.admin` | KMS 管理 |
| 11 | `roles/cloudsupport.admin` | サポート |
| 12 | `roles/compute.networkAdmin` | ネットワーク管理 |
| 13 | `roles/compute.securityAdmin` | FW/SSL 管理 |
| 14 | `roles/compute.xpnAdmin` | Shared VPC 管理 |
| 15 | `roles/logging.admin` | ログ管理 |
| 16 | `roles/monitoring.admin` | 監視管理 |
| 17 | `roles/pubsub.admin` | Pub/Sub 管理 |
| 18 | `roles/viewer` | 基本・全体 read |

**`gcp-billing-admins`（2 ロール）**

- `roles/billing.creator`
- `roles/resourcemanager.organizationViewer`

> ⚠️ **この18ロールは「全権の org 管理グループ1つ」に集約したもの**です。グループを使わず個人へ付与する小規模運用（`enable_group_iam=false`、→ [IAM 管理スコープと運用境界](../design/iam_management_scope.md)）では、**全員にこの18を配るのは過剰**です。役割に応じて配分し、管理者級は1〜2名＋break-glass に限定し、残りは `roles/viewer` ＋プロジェクト単位の実務ロールに留めるなど、最小権限で割り当ててください。使う予定のない機能のロール（`compute.xpnAdmin` 等）は付与しないこと。

#### バインド件数（回帰テストで固定）

組織レベル IAM のバインド件数は `terraform/2_organization/group_roles.tftest.hcl`（`mock_provider` による offline テスト）で固定しています。冗長ロールの追加・削除時はこの件数差分でレビューしてください。

| モード | バインド数 |
|---|---|
| 簡略（`enable_simplified_admin_groups=true`, `enable_group_iam=true`） | **20**（org-admins 18 + billing 2）|
| 本番（`enable_simplified_admin_groups=false`, `enable_group_iam=true`） | 40 |
| `enable_group_iam=false` | 0 |
