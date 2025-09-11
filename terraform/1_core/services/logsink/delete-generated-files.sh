#!/usr/bin/env bash
set -euo pipefail

rm -rf ./data.tf
rm -rf ./sinks.tf
rm -rf ./destinations.tf
rm -rf ./iam.tf

echo "Pythonスクリプトによるtfファイル生成をやり直すために data.tf, sinks.tf, destinations.tf, iam.tf を 削除しました"
