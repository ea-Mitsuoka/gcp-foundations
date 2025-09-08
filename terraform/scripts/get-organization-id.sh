#!/bin/bash
set -e

# 最上位の階層にある domain.env ファイルを読み込み、環境変数を設定
source ../../domain.env

# gcloudコマンドで組織IDを取得
ORG_ID=$(gcloud organizations list --filter="displayName=\"$domain\"" --format="value(ID)")

jq -n \
  --arg org_id "$ORG_ID" \
  '{"organization_id": $org_id}'
