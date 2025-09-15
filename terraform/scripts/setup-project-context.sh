#!/bin/bash
set -euo pipefail

# --- 1. プロジェクト名の自動特定 ---
CURRENT_DIR=$(pwd)
# 修正前コードの成功したロジックを採用し、パスからプロジェクト名 (例: logsink) を抽出
PROJECT_NAME=$(echo "$CURRENT_DIR" | sed -n 's|.*/services/\([^/]*\).*|\1|p')

# もし services/ からの抽出に失敗した場合、base/ からの抽出を試みる
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(echo "$CURRENT_DIR" | sed -n 's|.*/base/\([^/]*\).*|\1|p')
fi

# 4_projects からの抽出も試みる
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(echo "$CURRENT_DIR" | sed -n 's|.*/4_projects/\([^/]*\).*|\1|p')
fi


if [ -z "$PROJECT_NAME" ]; then
  echo "ERROR: Could not determine project name from current path: $CURRENT_DIR" >&2
  exit 1
fi
echo "INFO: Determined project context: [${PROJECT_NAME}]"

# --- 2. 対応するプロジェクト作成ディレクトリのパスを動的に探索 ---
REPO_ROOT=$(git rev-parse --show-toplevel)
# プロジェクトが作成される可能性のある場所のリスト
POSSIBLE_SOURCE_DIRS=(
  "${REPO_ROOT}/terraform/1_core/base/${PROJECT_NAME}"
  "${REPO_ROOT}/terraform/4_projects/base/${PROJECT_NAME}"
  # 互換性のために古い 'projects' パスも残す
  "${REPO_ROOT}/terraform/1_core/projects/${PROJECT_NAME}" 
)

SOURCE_PROJECT_DIR=""
for DIR in "${POSSIBLE_SOURCE_DIRS[@]}"; do
  if [ -d "$DIR" ]; then
    SOURCE_PROJECT_DIR="$DIR"
    break
  fi
done

if [ -z "$SOURCE_PROJECT_DIR" ]; then
  echo "ERROR: Source project directory for '${PROJECT_NAME}' not found." >&2
  exit 1
fi
echo "INFO: Found source project directory: ${SOURCE_PROJECT_DIR}"

# --- 3. ソースディレクトリから project_id を取得 ---
echo "INFO: Reading 'project_id' output from '${SOURCE_PROJECT_DIR}'..."
PROJECT_ID=$(terraform -chdir="$SOURCE_PROJECT_DIR" output -raw project_id)

if [ -z "$PROJECT_ID" ]; then
  echo "ERROR: Could not retrieve 'project_id' from '${SOURCE_PROJECT_DIR}'." >&2
  echo "HINT: Please run 'terraform apply' in the source project directory first." >&2
  exit 1
fi
echo "INFO: Retrieved Project ID: ${PROJECT_ID}"

# --- 4. カレントディレクトリの terraform.tfvars に書き込む ---
TFVARS_FILE="./terraform.tfvars"
# 汎用的な変数名 "project_id" を使用
KEY_TO_SET="project_id"
LINE_TO_ADD="${KEY_TO_SET} = \"${PROJECT_ID}\""

# 冪等性を保つ更新・追記ロジック
if [ -f "$TFVARS_FILE" ] && grep -q -E "^[[:space:]]*${KEY_TO_SET}[[:space:]]*=" "$TFVARS_FILE"; then
  sed -i.bak -E "s|^[[:space:]]*${KEY_TO_SET}[[:space:]]*=.*|${LINE_TO_ADD}|" "$TFVARS_FILE"
  rm -f "${TFVARS_FILE}.bak"
else
  if [ -s "$TFVARS_FILE" ]; then
    printf '\n%s\n' "${LINE_TO_ADD}" >> "$TFVARS_FILE"
  else
    printf '%s\n' "${LINE_TO_ADD}" > "$TFVARS_FILE"
  fi
fi

echo "✅ Successfully set '${KEY_TO_SET}' in '${TFVARS_FILE}'"
