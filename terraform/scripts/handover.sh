#!/bin/bash
set -e

# ------------------------------------------------------------------------------
# Repository Handover Script
# 元リポジトリ（.git・作業ツリー）には一切手を加えず、納品成果物だけを delivery/ に出力する。
#   delivery/<明細書>.xlsx : make delivery-doc が生成（本スクリプトの前段）
#   delivery/<repo>.zip    : 不要ファイルを除外し、git init/commit 済みツリーの git archive
# 破壊的処理はすべて一時ステージング(mktemp)上で行うため、元の .git は保持される。
#
# 顧客は zip 展開後、同梱のソース設定（common.tfvars / common.tfbackend / domain.env /
# gcp-foundations.xlsx）から `make generate && make plan` を実行し、環境との差分が無いことを
# 確認して Terraform 管理の運用を引き継げる（詳細は docs/operations/handover_procedure.md）。
# ------------------------------------------------------------------------------

echo "=========================================================="
echo " Preparing Repository for Customer Handover"
echo "=========================================================="

ROOT_DIR="$(git rev-parse --show-toplevel)"
DELIVERY_DIR="${ROOT_DIR}/delivery"
mkdir -p "$DELIVERY_DIR"

echo ">>> Staging a clean copy (original repository is left untouched)..."
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
rsync -a \
  --exclude='.git' \
  --exclude='.venv' \
  --exclude='.terraform' \
  --exclude='.terraform.lock.hcl' \
  --exclude='__pycache__' \
  --exclude='.test_mode_env' \
  --exclude='delivery' \
  "${ROOT_DIR}/" "${STAGING}/"

cd "$STAGING"

echo ">>> Configuring .gitignore for the customer repository..."
# 顧客が環境を再現・運用するために必要なものを納品に「含める」（除外を解除）:
#   - 自動生成コード(auto_*.tf)      … レビュー用に同梱
#   - 環境固有のソース設定           … common.tfvars / common.tfbackend / domain.env / gcp-foundations.xlsx
#     これらから `make generate` で 4_projects/ 等の派生コード一式を再生成できる。
# 一方、tfstate やローカルキャッシュ（.terraform 等）は引き続き除外する。
if [ -f ".gitignore" ]; then
  sed -e '/^\*\*\/auto_\*\.tf$/d' \
      -e '/^\*\.tfvars$/d' \
      -e '/^\*\.tfbackend$/d' \
      -e '/^domain\.env$/d' \
      -e '/^gcp-foundations\.xlsx$/d' \
      .gitignore > .gitignore.tmp
  mv .gitignore.tmp .gitignore
fi

echo ">>> Excluding internal-only documentation from the delivery..."
# 顧客は「環境の再現・運用」ができれば十分。開発のヒント・テンプレ保守・QA、
# 複数顧客への横断対応や事前移管のための社内向けドキュメントは納品から除外する。
cat >> .gitignore <<'EOF'

# --- Customer handover: internal-only docs (excluded by handover.sh) ---
docs/tests/
docs/development/
docs/ea-design/
docs/migration/
docs/design/todo.md
docs/design/generator_philosophy.md
docs/operations/module_maintenance.md
docs/operations/delivery_document_generation.md
docs/operations/spreadsheet_session_guide.md
docs/operations/handover_procedure.md

# テンプレートのテストスイート（QA 用のテストコード・フィクスチャ。顧客の環境再現・運用には不要）。
# ※ terraform モジュールのテスト(terraform/**/*.tftest.hcl)はコード側にあり対象外。
tests/

# handover.sh 自身は納品リポジトリに含めない（顧客が引き渡し処理を再実行できないように）。
# Makefile の `make delivery` は handover-wrap.sh 経由で呼ばれ、handover.sh が無ければ
# エラーで停止する。
terraform/scripts/handover.sh
EOF

echo ">>> Cleaning README references to non-delivered docs / vendor-only commands..."
# README は納品リポジトリにも含まれるため、納品で除外するドキュメントへのリンクや
# ベンダー専用コマンド(make delivery)の記述を行ごと削除し、リンク切れ・不要記述を防ぐ。
if [ -f "README.md" ]; then
  sed -e '/make delivery/d' \
      -e '/handover_procedure/d' \
      -e '/delivery_document_generation/d' \
      -e '/module_maintenance/d' \
      -e '/generator_philosophy/d' \
      -e '/ai_handoff/d' \
      -e '/spreadsheet_session_guide/d' \
      -e '/docs\/migration\//d' \
      -e '/docs\/tests\//d' \
      -e '/docs\/ea-design\//d' \
      -e '/docs\/development\//d' \
      README.md > README.md.tmp
  mv README.md.tmp README.md
fi

echo ">>> Creating a fresh Git history and exporting the archive..."
git init -q
git add .
git commit -q -m "Initial commit: GCP Foundations base architecture"

ARCHIVE_NAME="gcp-foundations_$(date +%Y%m%d).zip"
git archive --format=zip -o "${DELIVERY_DIR}/${ARCHIVE_NAME}" HEAD

cd "$ROOT_DIR"
echo "=========================================================="
echo " Handover complete. Original repository (.git) is preserved."
echo "=========================================================="
echo "Delivery artifacts in delivery/:"
ls -1 "$DELIVERY_DIR"
echo ""
echo "Next Steps:"
echo "Please refer to 'docs/operations/handover_procedure.md' to transfer GCP IAM permissions."
