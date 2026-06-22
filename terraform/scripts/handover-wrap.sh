#!/bin/bash
set -e

# ------------------------------------------------------------------------------
# Handover wrapper (`make delivery` から呼ばれる)
#
# handover.sh は「テンプレート（構築ベンダー）リポジトリ」にのみ同梱し、納品リポジトリには
# 含めない（handover.sh 自身が .gitignore 追記で自分を除外する）。
# したがって納品先で `make delivery` を実行しても handover.sh は存在せず、ここで明確に
# 拒否して終了する（顧客が誤って引き渡し処理を再実行するのを防ぐ）。
# ------------------------------------------------------------------------------

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HANDOVER="${ROOT_DIR}/terraform/scripts/handover.sh"

if [ ! -f "$HANDOVER" ]; then
  echo "❌ 'make delivery' はテンプレート（構築ベンダー）リポジトリ専用のコマンドです。" >&2
  echo "   この納品リポジトリでは引き渡し処理 (handover.sh) を実行できません。" >&2
  echo "   環境の運用には 'make generate' / 'make plan' / 'make deploy' をご利用ください。" >&2
  exit 1
fi

# テンプレートリポジトリ: 構築設定明細書を生成 → 納品アーカイブ(zip)を作成
uv run "${ROOT_DIR}/terraform/scripts/generate_delivery.py"
bash "$HANDOVER"
