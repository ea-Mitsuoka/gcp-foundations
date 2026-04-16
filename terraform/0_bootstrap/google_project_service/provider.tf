provider "google" {
  # ブートストラップ時は権限を借用せず、実行ユーザーのローカル権限を使用します
}

provider "google-beta" {
}