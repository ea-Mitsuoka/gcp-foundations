#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TFBACKEND="$SCRIPT_DIR/../../../../common.tfbackend"
TFVARS="$SCRIPT_DIR/terraform.tfvars"

if [ ! -f "$TFBACKEND" ]; then
  echo "error: $TFBACKEND が見つかりません" >&2
  exit 1
fi

# common.tfbackend から bucket = "..." の値を抽出
BUCKET="$(awk -F'"' '/^[[:space:]]*bucket[[:space:]]*=/{print $2; exit}' "$TFBACKEND" || true)"

if [ -z "$BUCKET" ]; then
  echo "error: common.tfbackend 内に bucket = \"...\" が見つかりません" >&2
  exit 1
fi

# terraform.tfvars があれば gcs_backend_bucket を置換、なければ作成して追記
if [ -f "$TFVARS" ] && grep -q -E '^[[:space:]]*gcs_backend_bucket[[:space:]]*=' "$TFVARS"; then
  # mac と GNU sed 両対応（-i の扱いが異なるため .bak を付ける）
  sed -i.bak -E "s|^[[:space:]]*gcs_backend_bucket[[:space:]]*=.*|gcs_backend_bucket=\"$BUCKET\"|" "$TFVARS"
  rm -f "${TFVARS}.bak"
else
  printf '%s\n' "gcs_backend_bucket=\"$BUCKET\"" >> "$TFVARS"
fi

echo "gcs_backend_bucket=\"$BUCKET\" を $TFVARS に設定しました"