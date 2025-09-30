WITH
-- 1. Asset Inventoryから権限を持つ全ユーザーを取得
all_permissioned_users AS (
  SELECT DISTINCT
    TRIM(member, 'user:') AS email
  FROM
    `__LOGSINK_PROJECT_ID__.asset_inventory.iam_policy`,
    UNNEST(policy.bindings) AS binding,
    UNNEST(binding.members) AS member
  WHERE
    STARTS_WITH(member, 'user:')
    AND NOT ENDS_WITH(TRIM(member, 'user:'), '.gserviceaccount.com')
),
-- 2. 監査ログから過去90日間に活動のあったユーザーを取得
active_users_last_90_days AS (
  SELECT DISTINCT
    protopayload_auditlog.authenticationInfo.principalEmail AS email
  FROM
    -- 管理アクセスログを参照しているが、必要に応じて他のログタイプも追加する
    `__LOGSINK_PROJECT_ID__.__LOGS_DATASET_ID__.cloudaudit_googleapis_com_activity`
  WHERE
    timestamp BETWEEN
      TIMESTAMP(FORMAT_DATE('%Y-%m-%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))) AND
      TIMESTAMP(FORMAT_DATE('%Y-%m-%d', CURRENT_DATE()))
    AND protopayload_auditlog.authenticationInfo.principalEmail IS NOT NULL
)
-- 3. (1)のリストにいて(2)のリストにいないユーザーを「非アクティブ」として抽出
SELECT
  apu.email
FROM
  all_permissioned_users AS apu
LEFT JOIN
  active_users_last_90_days AS au
ON
  apu.email = au.email
WHERE
  au.email IS NULL
