#!/usr/bin/env bash
set -euo pipefail

# スクリプトの場所からリポジトリのルートディレクトリ（.gitがある場所）を探す
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/.git" ]; do
  REPO_ROOT="$(dirname "$REPO_ROOT")"
done

# .gitが見つからなければエラー
if [ "$REPO_ROOT" == "/" ]; then
  echo "error: .git ディレクトリが見つかりません。リポジトリのルートを特定できませんでした。" >&2
  exit 1
fi

# ファイルパスを定義
DOMAIN_ENV_FILE="$REPO_ROOT/domain.env"
TFVARS_FILE="$REPO_ROOT/terraform/common.tfvars"
KEY="organization_domain"

# 1. domain.env の存在チェックと読み込み
if [ ! -f "$DOMAIN_ENV_FILE" ]; then
  echo "error: ソースファイルが見つかりません: $DOMAIN_ENV_FILE" >&2
  exit 1
fi

# domain.env の正規形式は `domain="example.com"` を想定。
# 旧形式（ファイルにドメイン文字列のみ）も互換として読み込む。
DOMAIN_VALUE=""
# shellcheck disable=SC1090
source "$DOMAIN_ENV_FILE" || true
if [ -n "${domain:-}" ]; then
  DOMAIN_VALUE="$domain"
else
  DOMAIN_VALUE="$(tr -d '[:space:]' < "$DOMAIN_ENV_FILE")"
fi

if [ -z "$DOMAIN_VALUE" ]; then
  echo "error: $DOMAIN_ENV_FILE が空か、読み込めません。" >&2
  exit 1
fi

# 2. common.tfvars への書き込み準備
LINE_TO_ADD="$KEY = \"$DOMAIN_VALUE\""
# 出力先のディレクトリが存在しない場合は作成
mkdir -p "$(dirname "$TFVARS_FILE")"

# 3. common.tfvars を更新または追記
# ファイル内に既に organization_domain が存在するかチェック
if [ -f "$TFVARS_FILE" ] && grep -q -E "^[[:space:]]*$KEY[[:space:]]*=" "$TFVARS_FILE"; then
  # 存在する場合：その行を置換する (macOS/GNU sed両対応)
  sed -i.bak -E "s|^[[:space:]]*$KEY[[:space:]]*=.*|$LINE_TO_ADD|" "$TFVARS_FILE"
  rm -f "${TFVARS_FILE}.bak"
  echo "✅ 更新しました: $TFVARS_FILE"
else
  # 存在しない場合：ファイルの末尾に追記する
  echo "$LINE_TO_ADD" >> "$TFVARS_FILE"
  echo "✅ 追記しました: $TFVARS_FILE"
fi

echo "---"
echo "設定内容: $LINE_TO_ADD"
