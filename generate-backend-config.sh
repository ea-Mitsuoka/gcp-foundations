#!/bin/bash
set -e

# .envファイルを読み込む
source ./domain.env

# ドメイン名のドットをハイフンに置換
SAFE_DOMAIN_NAME=$(echo "$domain" | tr '.' '-')

# バケット名を定義
BUCKET_NAME="tfstate-${SAFE_DOMAIN_NAME}-tf-admin"

# テンプレートファイルから置換を行い、最終的な設定ファイルを生成
sed "s/__BUCKET_NAME__/${BUCKET_NAME}/g" terraform/common.tfbackend.tpl > terraform/common.tfbackend

echo "terraform/common.tfbackend ファイルを生成しました。"
echo "Bucket Name: ${BUCKET_NAME}"
