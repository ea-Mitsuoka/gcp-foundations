#!/usr/bin/env bash
set -euo pipefail

# スクリプト配置ディレクトリを基準に上方向へ辿って repository ルートの domain.env を探す（get-organization-id.sh と同じ方針）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARCH_DIR="$SCRIPT_DIR"
DOMAIN_ENV=""

while [ "$SEARCH_DIR" != "/" ]; do
  if [ -f "$SEARCH_DIR/domain.env" ]; then
    DOMAIN_ENV="$SEARCH_DIR/domain.env"
    break
  fi
  SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done

if [ -z "$DOMAIN_ENV" ]; then
  echo "error: domain.env がリポジトリ内に見つかりません。リポジトリルートに domain.env を配置してください。" >&2
  exit 1
fi

# domain.env を読み込む（変数 domain を定義している想定）
# shellcheck disable=SC1090
source "$DOMAIN_ENV"

if [ -z "${domain:-}" ]; then
  echo "error: domain が domain.env に定義されていません" >&2
  exit 1
fi

# 組織名生成ルール：ドメインのドットをハイフンに置換（get-organization-id.sh と方針を統一）
ORG_NAME="$(echo "$domain" | tr '.' '-')"

# JSON を出力（external データソースは JSON を期待する）
jq -n --arg org_name "$ORG_NAME" '{"organization_name": $org_name}'
