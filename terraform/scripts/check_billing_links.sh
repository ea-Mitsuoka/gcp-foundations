#!/bin/bash
#
# check_billing_links.sh
# ------------------------------------------------------------------------------
# 「manual」課金運用（billing_account = "manual"）のプロジェクトについて、
# 実際に課金アカウントがリンクされているかを apply 前に検証する。
#
# 背景:
#   本基盤は「課金リンク済み」を前提に API 有効化・各リソース作成・予算を組む。
#   billing_account が "" (global) / "<id>" のプロジェクトは Terraform が課金を
#   リンクするため問題ないが、"manual" のプロジェクトは Terraform が課金を一切
#   管理しない（既存リンク／手動運用前提）。ここで課金が未リンクだと、後続の
#   API 有効化などが不明瞭なエラーで失敗する。それを apply 前に検知して止める。
#
# 使い方:
#   check_billing_links.sh [PLAN_ONLY]
#     PLAN_ONLY = "true" の場合は plan は課金に依存しないため、未リンクでも
#     エラーにはせず警告に留める（apply では未リンクを検出したら停止＝exit 1）。
# ------------------------------------------------------------------------------

set -uo pipefail

print_info()    { echo -e "\033[34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
print_error()   { echo -e "\033[31m[ERROR]\033[0m $1"; }

PLAN_ONLY="${1:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
COMMON_TFVARS="${REPO_ROOT}/terraform/common.tfvars"
PROJECTS_DIR="${REPO_ROOT}/terraform/4_projects"

# tfvars から値を1つ取り出す（`key = "value"` / `key = value` の両対応）
extract_tfvar() {
    local file="$1" key="$2"
    sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$file" | head -1 | tr -d ' "'
}

# --- CI／認証なしはスキップ（preflight_check.sh と同じ方針） ---
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    print_warning "No active GCP credentials. Skipping manual billing-link verification."
    exit 0
fi

if [ ! -d "$PROJECTS_DIR" ]; then
    exit 0
fi

PROJECT_ID_PREFIX=""
if [ -f "$COMMON_TFVARS" ]; then
    PROJECT_ID_PREFIX="$(extract_tfvar "$COMMON_TFVARS" "project_id_prefix")"
fi

print_info "Verifying billing links for 'manual' billing projects..."

CHECKED=0
FAIL=0
for tfvars in "$PROJECTS_DIR"/*/terraform.tfvars; do
    [ -f "$tfvars" ] || continue

    billing="$(extract_tfvar "$tfvars" "billing_account")"
    # Terraform が課金を管理するモード（""=global / "<id>"）は TF が apply 時にリンク
    # するため事前検証は不要。検証対象は "manual"（TF 非管理）のみ。
    [ "$billing" = "manual" ] || continue

    existing="$(extract_tfvar "$tfvars" "existing_project_id")"
    app="$(extract_tfvar "$tfvars" "app_name")"
    if [ -n "$existing" ]; then
        pid="$existing"
    else
        pid="${PROJECT_ID_PREFIX}-${app}"
    fi

    CHECKED=$((CHECKED + 1))

    describe_out="$(gcloud billing projects describe "$pid" --format="value(billingEnabled)" 2>&1)"
    rc=$?
    if [ $rc -ne 0 ]; then
        print_error "[$pid] billing_account=manual ですが課金情報を取得できません。"
        echo "         詳細: ${describe_out}"
        echo "         → プロジェクトが未作成、または実行者に billing 参照権限"
        echo "           (roles/billing.viewer 等) がない可能性があります。"
        echo "         手動リンク: gcloud billing projects link ${pid} --billing-account=<BILLING_ACCOUNT_ID>"
        FAIL=$((FAIL + 1))
    elif [ "$describe_out" != "True" ]; then
        print_error "[$pid] billing_account=manual ですが課金アカウントがリンクされていません (billingEnabled=${describe_out})。"
        echo "         手動リンク: gcloud billing projects link ${pid} --billing-account=<BILLING_ACCOUNT_ID>"
        echo "         参考: docs/operations/project_lifecycle.md 「課金アカウントのリンク」"
        FAIL=$((FAIL + 1))
    else
        print_success "[$pid] billing linked (manual mode)."
    fi
done

if [ "$CHECKED" -eq 0 ]; then
    print_info "No 'manual' billing projects to verify."
    exit 0
fi

if [ "$FAIL" -ne 0 ]; then
    if [ "$PLAN_ONLY" = "true" ]; then
        print_warning "${FAIL} project(s) with billing_account=manual are not linked. (plan-only: continuing)"
        exit 0
    fi
    print_error "${FAIL} project(s) with billing_account=manual are not linked. Aborting before apply."
    echo "  課金リンクは Terraform では管理されません。上記コマンドで手動リンクしてから 'make deploy' を再実行してください。"
    exit 1
fi

print_success "All 'manual' billing projects are linked."
exit 0
