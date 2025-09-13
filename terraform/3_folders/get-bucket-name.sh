#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCALS_TF="./locals.tf"

# --- ここからが修正部分 ---

# 上位階層に向かって common.tfbackend を再帰的に探索
SEARCH_DIR="$SCRIPT_DIR"
TFBACKEND="" # 見つかったファイルのパスを格納する変数を初期化

# ルートディレクトリ (/) に到達するまでループ
while [ "$SEARCH_DIR" != "/" ]; do
  if [ -f "$SEARCH_DIR/common.tfbackend" ]; then
    # ファイルが見つかったら、パスを格納してループを抜ける
    TFBACKEND="$SEARCH_DIR/common.tfbackend"
    break
  fi
  # 見つからなければ、一つ上のディレクトリへ移動
  SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done

# --- ここまでが修正部分 ---

# ファイルが見つからなかった場合のエラーチェック
if [ -z "$TFBACKEND" ]; then
  echo "error: 上位階層に common.tfbackend が見つかりません" >&2
  exit 1
fi

# common.tfbackend から bucket の値を抽出
BUCKET="$(awk -F'"' '/^[[:space:]]*bucket[[:space:]]*=/{print $2; exit}' "$TFBACKEND" || true)"

if [ -z "$BUCKET" ]; then
  echo "error: $TFBACKEND 内に bucket = \"...\" が見つかりません" >&2
  exit 1
fi

# --- locals.tf の修正ロジック (変更なし) ---

# Case 1: locals.tf ファイルが存在しない場合
if [ ! -f "$LOCALS_TF" ]; then
  # ファイルを新規作成してlocalsブロックと属性を書き込む
  printf 'locals {\n  gcs_backend_bucket = "%s"\n}\n' "$BUCKET" > "$LOCALS_TF"
  echo "✅ 新規作成した $LOCALS_TF に gcs_backend_bucket を設定しました。"
  exit 0
fi

# Case 2: locals.tf ファイルが存在する場合
# 2a: 既に gcs_backend_bucket 属性が存在するか確認
if grep -q -E '^[[:space:]]*gcs_backend_bucket[[:space:]]*=' "$LOCALS_TF"; then
  # 存在する場合、その行の値を置換する (macOS と GNU sed 両対応)
  sed -i.bak -E "s|^([[:space:]]*gcs_backend_bucket[[:space:]]*=).*|\1 \"$BUCKET\"|" "$LOCALS_TF"
  rm -f "${LOCALS_TF}.bak"
  echo "✅ 既存の $LOCALS_TF 内の gcs_backend_bucket を更新しました。"
else
  # 2b: gcs_backend_bucket 属性が存在しない場合、localsブロックがあるか確認
  if grep -q -E '^[[:space:]]*locals[[:space:]]*\{' "$LOCALS_TF"; then
    # localsブロックが存在する場合、そのブロックの直下に属性を挿入する
    sed -i.bak "/^[[:space:]]*locals[[:space:]]*{/a\\
  gcs_backend_bucket = \"$BUCKET\"
" "$LOCALS_TF"
    rm -f "${LOCALS_TF}.bak"
    echo "✅ 既存の $LOCALS_TF の locals ブロックに gcs_backend_bucket を追加しました。"
  else
    # localsブロックも存在しない場合、ファイルの末尾に新しいブロックを追記する
    printf '\nlocals {\n  gcs_backend_bucket = "%s"\n}\n' "$BUCKET" >> "$LOCALS_TF"
    echo "✅ 既存の $LOCALS_TF に locals ブロックと gcs_backend_bucket を追記しました。"
  fi
fi
