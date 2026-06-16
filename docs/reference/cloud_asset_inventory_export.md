# 監査基盤 BigQuery 活用ガイド（asset_inventory / audit_logs）

本ドキュメントでは、本基盤において自動構築される 2 つの監査用 BigQuery データセットの仕様と、監査・フォレンジック・棚卸しに活用するための実践的な SQL クエリ集をまとめます。

| データセット | 何が入るか | 答えられる問い |
| :--- | :--- | :--- |
| `asset_inventory`（Cloud Asset Inventory） | 組織／フォルダ／プロジェクトの **IAM ポリシーの現況と変更履歴** | **誰が・どのリソースに・何の権限を持っているか** |
| `audit_logs`（Cloud Audit Logs 集約） | 組織横断の **管理アクティビティ監査ログ**（誰が何の操作をしたか） | **誰が・いつ・何の操作を行使したか** |

> 両者は補完関係です。`asset_inventory` で「不審な権限がある」と気づき、`audit_logs` で「それを付けた人物・操作」を特定する、という流れで使います（第 4 章・第 5 章）。

> **`[YOUR_PROJECT_ID]`** は集約先プロジェクト（`<prefix>-logsink`、本番では `me-ai-logsink` 等）に読み替えてください。

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

## 3. asset_inventory（IAM 台帳）クエリ集

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

### 3.5 【履歴】特定リソースの IAM 変更タイムライン

「いつ権限構成が変わったか」を時系列で確認します（タイムトラベル）。

```sql
SELECT
  event_time,
  asset_type,
  is_deleted,
  binding.role,
  member
FROM
  `[YOUR_PROJECT_ID].asset_inventory.v_iam_policy`,
  UNNEST(policy_bindings) AS binding,
  UNNEST(binding.members) AS member
WHERE
  resource_name LIKE '%projects/[TARGET_PROJECT_NUMBER]'   -- 対象リソースで絞る
ORDER BY
  event_time DESC;
```

______________________________________________________________________

## 4. audit_logs（Cloud Audit Logs）クエリ集

**「誰が・いつ・何の操作をしたか（Who / When / What）」** を調べるデータセットです。

> **テーブルについて**
> - 物理テーブルは **日付パーティション表** `cloudaudit_googleapis_com_activity`（単一テーブル）です。`_TABLE_SUFFIX` を使う**ワイルドカード（`..._*`）ではありません**。絞り込みは **パーティション列 `timestamp`** で行ってください（スキャン量の削減にもなります）。
> - 本基盤の組織集約シンクは **管理アクティビティ監査ログ**（書き込み系操作）のみを集約しています（Data Access 監査ログは費用面から既定で対象外）。

### 4.1 直近の操作（誰が・いつ・何を）

```sql
SELECT
  timestamp,
  protopayload_auditlog.authenticationInfo.principalEmail AS actor,
  protopayload_auditlog.methodName                        AS method,
  protopayload_auditlog.serviceName                       AS service,
  protopayload_auditlog.resourceName                      AS resource,
  protopayload_auditlog.requestMetadata.callerIp          AS caller_ip
FROM
  `[YOUR_PROJECT_ID].audit_logs.cloudaudit_googleapis_com_activity`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
ORDER BY
  timestamp DESC
LIMIT 200;
```

### 4.2 特定ユーザーの操作履歴を追う

```sql
SELECT
  timestamp,
  protopayload_auditlog.methodName  AS method,
  protopayload_auditlog.resourceName AS resource
FROM
  `[YOUR_PROJECT_ID].audit_logs.cloudaudit_googleapis_com_activity`
WHERE
  protopayload_auditlog.authenticationInfo.principalEmail = 'user@example.com'  -- 調査対象
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
ORDER BY
  timestamp DESC;
```

### 4.3 【権限変更】SetIamPolicy（誰が IAM を変更したか）

```sql
SELECT
  timestamp,
  protopayload_auditlog.authenticationInfo.principalEmail AS actor,
  protopayload_auditlog.resourceName                      AS resource,
  protopayload_auditlog.methodName                        AS method
FROM
  `[YOUR_PROJECT_ID].audit_logs.cloudaudit_googleapis_com_activity`
WHERE
  protopayload_auditlog.methodName LIKE '%SetIamPolicy%'
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
ORDER BY
  timestamp DESC;
```

### 4.4 【組織ポリシー】DryRun 違反ログの確認

DryRun 中の制約に「違反したはず」の操作を抽出します（操作自体は成功＝本適用なら拒否されていた予告）。**0 行＝違反なし**です。

```sql
SELECT
  timestamp,
  protopayload_auditlog.authenticationInfo.principalEmail AS actor,
  protopayload_auditlog.methodName                        AS method,
  protopayload_auditlog.policyViolationInfo.orgPolicyViolationInfo AS violation
FROM
  `[YOUR_PROJECT_ID].audit_logs.cloudaudit_googleapis_com_activity`
WHERE
  protopayload_auditlog.policyViolationInfo IS NOT NULL
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
ORDER BY
  timestamp DESC;
```

### 4.5 【失敗・拒否】エラーになった操作のみ抽出

```sql
SELECT
  timestamp,
  protopayload_auditlog.authenticationInfo.principalEmail AS actor,
  protopayload_auditlog.methodName                        AS method,
  protopayload_auditlog.status.code                       AS status_code,
  protopayload_auditlog.status.message                    AS status_message
FROM
  `[YOUR_PROJECT_ID].audit_logs.cloudaudit_googleapis_com_activity`
WHERE
  protopayload_auditlog.status.code IS NOT NULL
  AND protopayload_auditlog.status.code != 0              -- 0 以外＝失敗/拒否
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
ORDER BY
  timestamp DESC;
```

### 4.6 【特定操作】サービスアカウント鍵の作成試行

```sql
SELECT
  timestamp,
  protopayload_auditlog.authenticationInfo.principalEmail AS actor,
  protopayload_auditlog.resourceName                      AS resource
FROM
  `[YOUR_PROJECT_ID].audit_logs.cloudaudit_googleapis_com_activity`
WHERE
  protopayload_auditlog.methodName LIKE '%CreateServiceAccountKey%'
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
ORDER BY
  timestamp DESC;
```

______________________________________________________________________

## 5. 2 つのデータの使い分け

| 問い | 使うデータ | 代表クエリ |
| :--- | :--- | :--- |
| 今、誰が何の権限を持っているか（棚卸し） | `asset_inventory` | 3.1 / 3.2 |
| 自社ドメイン外への付与はないか | `asset_inventory` | 3.3 |
| いつ権限構成が変わったか（履歴） | `asset_inventory` | 3.5 |
| 誰が・いつ・何を操作したか | `audit_logs` | 4.1 / 4.2 |
| 誰が IAM を変更したか（犯人特定） | `audit_logs`（必要に応じ `asset_inventory` と結合） | 4.3 / 3.4 |
| 組織ポリシー DryRun 違反の有無 | `audit_logs` | 4.4 |
| 失敗・拒否された操作 | `audit_logs` | 4.5 |

> **まとめ**: `asset_inventory` ＝「**誰が権限を持っているか**（状態と履歴）」、`audit_logs` ＝「**誰が権限を行使したか**（操作の記録）」。ISMS のアクセス制御証跡は、この 2 つで「保有」と「行使」の両面を担保できます。
