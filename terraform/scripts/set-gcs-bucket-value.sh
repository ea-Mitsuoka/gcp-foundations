#!/usr/bin/env bash
set -euo pipefail

# --- 1. 引数のチェック ---
if [ -z "$1" ]; then
  echo "エラー: 操作対象のディレクトリパスが指定されていません。" >&2
  echo "使い方: $0 <path/to/target_directory>" >&2
  exit 1
fi
TARGET_DIR="$1"

# --- 2. gitコマンドでリポジトリのルートパスを直接取得 ---
# git rev-parse --show-toplevel を使い、リポジトリのルートを特定
REPO_ROOT=$(git rev-parse --show-toplevel)

# エラーチェック: gitコマンドが失敗した場合や、リポジトリ外で実行された場合
if [ -z "$REPO_ROOT" ]; then
  echo "エラー: Gitリポジトリのルートが見つかりません。" >&2
  exit 1
fi

# --- 3. 取得したルートパスを基準に、各ファイルのパスを定義 ---
TFBACKEND="$REPO_ROOT/terraform/common.tfbackend"
TFVARS="$TARGET_DIR/terraform.tfvars"

# --- 4. バケット名の読み込み ---
if [ ! -f "$TFBACKEND" ]; then
  echo "error: $TFBACKEND が見つかりません" >&2
  exit 1
fi
BUCKET="$(awk -F'"' '/^[[:space:]]*bucket[[:space:]]*=/{print $2; exit}' "$TFBACKEND" || true)"

if [ -z "$BUCKET" ]; then
  echo "error: common.tfbackend 内に bucket = \"...\" が見つかりません" >&2
  exit 1
fi

# --- 5. 対象のtfvarsファイルを更新または追記 ---
KEY="gcs_backend_bucket"
LINE_TO_WRITE="$KEY = \"$BUCKET\""

if [ -f "$TFVARS" ] && grep -q -E "^[[:space:]]*$KEY[[:space:]]*=" "$TFVARS"; then
  sed -i.bak -E "s|^([[:space:]]*$KEY[[:space:]]*=).*|$LINE_TO_WRITE|" "$TFVARS"
  rm -f "${TFVARS}.bak"
else
  if [ -s "$TFVARS" ]; then
    printf '\n%s\n' "$LINE_TO_WRITE" >> "$TFVARS"
  else
    printf '%s\n' "$LINE_TO_WRITE" > "$TFVARS"
  fi
fi

echo "✅ gcs_backend_bucket=\"$BUCKET\" を $TFVARS に設定しました。"
