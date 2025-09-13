terraform {
  backend "gcs" {
    # terraform initコマンドのオプションでバケットを指定する
    # このディレクトリ用のtfstateの保存場所を区別するためのprefix
    prefix = "core/services/logsink/google_project_service"
  }
}