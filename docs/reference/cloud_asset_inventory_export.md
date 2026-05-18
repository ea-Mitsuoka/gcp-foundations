# Cloud Asset Inventory (CAI) BigQuery エクスポート仕様書

本ドキュメントでは、本基盤において自動構築される Cloud Asset Inventory (CAI) の BigQuery 連携アーキテクチャ、テーブル仕様、および監査・フォレンジックに活用するための実践的な SQL クエリについて解説します。

______________________________________________________________________

## 1. アーキテクチャと更新の仕組み

本基盤では、組織内のリソースや IAM の変更を「ニアリアルタイム」で BigQuery に記録するアーキテクチャを採用しています。

### 1.1 サーバーレス（NoOps）アーキテクチャ

Cloud Run や Cloud Functions などのコンピュートリソースは一切使用せず、GCP のネイティブ機能のみを直結させています。これにより、コードのバグによる停止リスクがなく、保守コストゼロで無限にスケールします。

1. **CAI リアルタイムフィード**: 組織内の IAM 変更イベントを自動検知します。
1. **Cloud Pub/Sub**: 検知した変更データを JSON (内部 AVRO) メッセージとして受け取ります。
1. **BigQuery サブスクリプション**: Pub/Sub のネイティブ機能により、届いたメッセージを直接 BigQuery のテーブルへ書き込みます。

### 1.2 データの更新方式 (Append-Only)

BigQuery に作成されるテーブルは、既存のデータを上書き（UPDATE）する「日別スナップショット」ではありません。
**「変更イベントが発生するたびに、その時点の最新状態が新しい行として追記（INSERT）され続ける履歴テーブル」** です。

______________________________________________________________________

## 2. テーブルとスキーマ仕様

データは `logsink` プロジェクト内の以下の場所に格納されます。

- **データセット名**: `asset_inventory`
- **物理テーブル名 (生データ)**: `iam_policy` (JSON型の `data` カラムのみ)
- **分析用ビュー (展開済み)**: `v_iam_policy` ★分析にはこちらを使用します

### 2.1 分析用ビュー (`v_iam_policy`) のスキーマ

複雑な生 JSON データを BigQuery で分析しやすい形に Terraform が自動で展開したビューです。分析時に頻繁に使用する主要カラムは以下の通りです。

| カラム名 | 型 | 説明 |
| :--- | :--- | :--- |
| `event_time` | TIMESTAMP | イベント発生日時（`window.startTime`） |
| `asset_type` | STRING | アセットの種類（例: `cloudresourcemanager.googleapis.com/Project`） |
| `resource_name` | STRING | 対象リソースのフルURI（例: `//cloudresourcemanager.googleapis.com/projects/123456789`） |
| `policy_bindings` | ARRAY<STRUCT> | 権限の割り当てリスト（Role と Members のペアの配列） |
| `policy_bindings.role` | STRING | 付与された IAM ロール（例: `roles/owner`） |
| `policy_bindings.members` | ARRAY<STRING> | 権限を持つメンバーの配列（例: `user:admin@...`, `group:admins@...`） |
| `is_deleted` | BOOL | アセットやポリシーが削除されたイベントかどうかのフラグ |

> **⚠️ 注意点**
> CAI のデータには「その状態に変更した犯人（Who）」は記録されません。「誰が変更したか」を特定する場合は、Cloud Audit Logs と結合して調査する必要があります。

______________________________________________________________________

## 3. 実践的な SQL クエリ集

データが「追記型（Append-Only）」であるため、現在の最新状態を取得するには `QUALIFY ROW_NUMBER() OVER (...) = 1` を使用して、リソースごとの最新行のみを抽出するのがベストプラクティスです。

### 3.1 【棚卸し】現在の最新の IAM ポリシー一覧を取得

過去の変更履歴を除外して、**「今現在」** の各リソースの権限状態をリストアップします。

```sql
SELECT
  resource_name,
  binding.role,
  member
FROM
  `[YOUR_PROJECT_ID].asset_inventory.v_iam_policy`,
  UNNEST(policy_bindings) AS binding,
  UNNEST(binding.members) AS member
WHERE
  1=1
-- リソースごとに最も新しいイベント日時の1行だけを抽出
QUALIFY ROW_NUMBER() OVER (PARTITION BY resource_name ORDER BY event_time DESC) = 1
ORDER BY
  resource_name, binding.role;
```

### 3.2 【特権監査】現在「オーナー」または「編集者」権限を持つユーザーの特定

サービスアカウントを除外し、人（ユーザー）に付与された特権を洗い出します。

```sql
SELECT
  resource_name,
  binding.role,
  member
FROM
  `[YOUR_PROJECT_ID].asset_inventory.v_iam_policy`,
  UNNEST(policy_bindings) AS binding,
  UNNEST(binding.members) AS member
WHERE
  binding.role IN ('roles/owner', 'roles/editor')
  AND member LIKE 'user:%'
QUALIFY ROW_NUMBER() OVER (PARTITION BY resource_name ORDER BY event_time DESC) = 1
ORDER BY
  resource_name;
```

### 3.3 【情報漏洩対策】自社ドメイン以外の権限付与を検知

フリーアドレス（`@gmail.com`）や外部ベンダーなど、許可されていないドメインへの権限付与がないかを監視します。

```sql
SELECT
  resource_name,
  binding.role,
  member
FROM
  `[YOUR_PROJECT_ID].asset_inventory.v_iam_policy`,
  UNNEST(policy_bindings) AS binding,
  UNNEST(binding.members) AS member
WHERE
  member LIKE 'user:%'
  AND member NOT LIKE '%@example.com' -- ここを自社のドメインに変更
QUALIFY ROW_NUMBER() OVER (PARTITION BY resource_name ORDER BY event_time DESC) = 1;
```

### 3.4 【フォレンジック】「誰が変更したか」を Audit Logs と結合して追跡

「不審な権限が追加されている」と CAI で発覚した際に、ログ集約基盤の Cloud Audit Logs と突き合わせて「その設定を行った人物（犯人）」を特定します。

```sql
-- 注: audit_logsデータセット名は環境に合わせて変更してください
SELECT
  audit.timestamp AS event_time,
  audit.protopayload_auditlog.authenticationInfo.principalEmail AS changed_by_who, -- 操作実行者
  cai.resource_name AS target_resource,
  binding.role AS granted_role,
  member AS granted_to_whom
FROM
  `[YOUR_PROJECT_ID].audit_logs.cloudaudit_googleapis_com_activity` AS audit
JOIN
  `[YOUR_PROJECT_ID].asset_inventory.v_iam_policy` AS cai
  -- Audit Logのラベルと、CAIのリソースIDを結合
  ON audit.resource.labels.project_id = SPLIT(cai.resource_name, '/')[ARRAY_LENGTH(SPLIT(cai.resource_name, '/')) - 1]
CROSS JOIN
  UNNEST(cai.policy_bindings) AS binding
CROSS JOIN
  UNNEST(binding.members) AS member
WHERE
  audit.protopayload_auditlog.methodName = 'SetIamPolicy'
  AND audit.timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY) -- 直近7日間
ORDER BY
  audit.timestamp DESC;
```
