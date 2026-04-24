# 複数環境 (dev, stag, prod) の管理について

本リポジトリでは、Terraform Workspaceを用いた環境管理は**行いません**。

各環境 (dev, stag, prod) は、Single Source of Truth (SSOT) である `gcp_foundations.xlsx` における**個別の行として定義**され、物理的に別々のディレクトリ (`terraform/4_projects/<app_name>`) として分離・管理されます。

これにより、以下のメリットがあります。

- 各環境の構成コードが物理的に分離されるため、変更時の影響範囲が明確になります。
- 環境ごとの状態 (State) が別のパスで管理され、設定ミスの波及を防ぎます。

詳細は、`docs/operations/add_new_project.md` を参照してください。
