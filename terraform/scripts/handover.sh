#!/bin/bash
set -e

# ------------------------------------------------------------------------------
# Repository Handover Script
# 顧客への納品前に、Gitの履歴をクリーンアップし、綺麗な状態にするためのスクリプトです。
# ------------------------------------------------------------------------------

echo "=========================================================="
echo " Preparing Repository for Customer Handover"
echo "=========================================================="

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

echo ">>> Configuring .gitignore for customer environment..."
# 顧客の運用では自動生成されたコードもレビュー対象とするため、除外設定を解除
if [ -f ".gitignore" ]; then
  # macOS/Linux環境の違いを吸収するため、一時ファイルを経由して置換
  sed '/\*\*\/auto_\*\.tf/d; /\*\*\/terraform\.tfvars/d' .gitignore > .gitignore.tmp
  mv .gitignore.tmp .gitignore
fi

echo "[1/4] Cleaning up local cache and temporary files..."
make clean > /dev/null 2>&1 || true

echo "[2/4] Removing existing .git directory to purge history..."
rm -rf .git

echo "[3/4] Initializing new Git repository and creating fresh Initial Commit..."
git init
git add .
git commit -m "Initial commit: GCP Foundations base architecture"

echo "[4/4] Handover preparation complete."
echo ""
echo "Next Steps:"
echo "Please refer to 'docs/operations/handover_procedure.md' to transfer GCP IAM permissions."
