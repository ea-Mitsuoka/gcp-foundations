locals {
  # スクリプト格納場所の候補（モジュールの位置が変わっても対応するため複数列挙）
  candidate_paths = [
    "${path.module}/../../../scripts",
    "${path.module}/../../scripts",
    "${path.module}/../scripts",
    "${path.root}/terraform/scripts",
    "${path.root}/../terraform/scripts",
  ]

  # 存在する候補だけ残す
  existing_candidates = [for p in local.candidate_paths : p if fileexists("${p}/get-organization-id.sh")]

  # 見つかればそれを、見つからなければ最初の候補をフォールバックとして使う
  scripts_dir = length(local.existing_candidates) > 0 ? local.existing_candidates[0] : local.candidate_paths[0]
}