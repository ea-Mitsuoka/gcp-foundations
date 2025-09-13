#!/bin/bash
set -e

# --- domain.env を上位ディレクトリまで探す ---
ENV_FILE=""
SEARCH_DIR="$(pwd)"
while [ "$SEARCH_DIR" != "/" ]; do
  if [ -f "$SEARCH_DIR/domain.env" ]; then
    ENV_FILE="$SEARCH_DIR/domain.env"
    break
  fi
  SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done

if [ -z "$ENV_FILE" ]; then
  echo "domain.env が見つかりませんでした。" >&2
  exit 1
fi

# domain.env の中身をそのまま読み込む（例：my-domain.com）
domain=$(<"$ENV_FILE")

# ドメイン名のドットをハイフンに置換
SAFE_DOMAIN_NAME=$(echo "$domain" | tr '.' '-')

# バケット名を定義
BUCKET_NAME="tfstate-${SAFE_DOMAIN_NAME}-tf-admin"

# domain.env のディレクトリと terraform ディレクトリ
BASE_DIR=$(dirname "$ENV_FILE")
TERRAFORM_DIR="${BASE_DIR}/terraform"

# テンプレートファイルから置換を行い、最終的な設定ファイルを生成
sed "s/__BUCKET_NAME__/${BUCKET_NAME}/g" \
  "${TERRAFORM_DIR}/common.tfbackend.tpl" > \
  "${TERRAFORM_DIR}/common.tfbackend"

echo "${TERRAFORM_DIR}/common.tfbackend ファイルを生成しました。"
echo "Bucket Name: ${BUCKET_NAME}"
