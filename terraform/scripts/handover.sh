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

echo "[1/3] Removing existing .git directory to purge history..."
rm -rf .git

echo "[2/3] Initializing new Git repository and creating fresh Initial Commit..."
git init
git add .
git commit -m "Initial commit: GCP Foundations base architecture"

echo "[3/3] Handover preparation complete."
echo ""
echo "Next Steps:"
echo "Please refer to 'docs/operations/handover_to_customer.md' to transfer GCP IAM permissions."
