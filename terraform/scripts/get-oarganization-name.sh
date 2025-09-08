#!/bin/bash
set -e

# 最上位の階層にある domain.env ファイルを読み込み、環境変数を設定
source ../../domain.env

# ドメイン名のドットをハイフンに置換
ORG_NAME=$(echo "$domain" | tr '.' '-')

jq -n \
  --arg org_name "$ORG_NAME" \
  '{"organization_name": $org_name}'
