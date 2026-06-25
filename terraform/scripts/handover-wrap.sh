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

# 削除保護の確認（非破壊・apply はしない）。
# allow_resource_destruction = true（削除保護OFF）のまま納品しようとしている場合は警告し、
# 続行可否を対話で確認する。通常は false（保護ON）で引き渡すのが安全（先に false →
# make generate → make deploy で実環境に保護を適用してから make delivery する）。
TFVARS="${ROOT_DIR}/terraform/common.tfvars"
if [ -f "$TFVARS" ]; then
  ALLOW_DESTROY="$(grep -E '^[[:space:]]*allow_resource_destruction[[:space:]]*=' "$TFVARS" \
    | head -1 | sed -E 's/.*=[[:space:]]*([A-Za-z]+).*/\1/')"
  if [ "$ALLOW_DESTROY" = "true" ]; then
    echo "⚠️  common.tfvars: allow_resource_destruction = true（削除保護 OFF）の状態です。" >&2
    echo "    このまま納品すると、削除保護が無効なリポジトリを引き渡します。" >&2
    echo "    推奨: false（保護 ON）に変更 → make generate → make deploy で実環境に適用してから納品。" >&2
    if [ "${DELIVERY_ALLOW_DESTRUCTION_ACK:-}" = "1" ]; then
      echo "    DELIVERY_ALLOW_DESTRUCTION_ACK=1 のため続行します。" >&2
    elif [ -t 0 ]; then
      printf "    削除保護 OFF のまま続行しますか？ [y/N]: " >&2
      read -r _ans
      case "$_ans" in
        y | Y | yes | YES) echo "    続行します。" >&2 ;;
        *) echo "    中止しました。" >&2; exit 1 ;;
      esac
    else
      echo "    非対話実行のため中止します（続行する場合は DELIVERY_ALLOW_DESTRUCTION_ACK=1 を指定）。" >&2
      exit 1
    fi
  fi
fi

# テンプレートリポジトリ: 構築設定明細書を生成 → 納品アーカイブ(zip)を作成
uv run "${ROOT_DIR}/terraform/scripts/generate_delivery.py"
bash "$HANDOVER"
