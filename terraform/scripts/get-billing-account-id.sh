#!/bin/bash
set -e

# gcloudコマンドで課金アカウントIDを取得
BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" --limit=1)

# 結果をTerraformが読み取れる単一のJSON形式で標準出力に出力
jq -n \
  --arg billing_id "$BILLING_ACCOUNT_ID" \
  '{"billing_account_id": $billing_id}'
