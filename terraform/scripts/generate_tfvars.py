# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "openpyxl==3.1.2",
# ]
# ///
import os
import shutil
import glob
import openpyxl

# domain.envからドメインを読み込む
domain_env_path = os.path.join(os.path.dirname(__file__), '../../domain.env')
domain = ""
with open(domain_env_path, 'r') as f:
    for line in f:
        if line.startswith('domain='):
            domain = line.split('=')[1].strip().strip('"')
            break

sanitized_domain = domain.replace('.', '-')

# xlsxファイルを読み込み、tfvarsを生成するロジック
xlsx_path = os.path.join(os.path.dirname(__file__), '../../projects_config.xlsx')

if os.path.exists(xlsx_path):
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    # 最初のアクティブなシートを使用する
    sheet = wb.active
    
    # 1行目をヘッダーとして取得
    headers = [cell.value for cell in sheet[1]]
    
    # 2行目以降のデータを行ごとに処理
    for row_idx, row in enumerate(sheet.iter_rows(min_row=2, values_only=True), start=2):
        if not any(row): continue # 空行はスキップ
        
        row_dict = dict(zip(headers, row))
        app_name = row_dict.get('app_name')
        if not app_name: continue

        project_dir = os.path.join(os.path.dirname(__file__), f"../../terraform/4_projects/{app_name}")
        example_dir = os.path.join(os.path.dirname(__file__), "../../terraform/4_projects/example_project")
        
        # 新規プロジェクトの場合、example_project から構成ファイルをコピー
        if not os.path.exists(project_dir):
            os.makedirs(project_dir, exist_ok=True)
            for tf_file in glob.glob(os.path.join(example_dir, '*.tf')):
                shutil.copy(tf_file, project_dir)
            
            # backend.tf の prefix (保存先パス) を新プロジェクト用に書き換え
            backend_path = os.path.join(project_dir, 'backend.tf')
            if os.path.exists(backend_path):
                with open(backend_path, 'r') as f:
                    content = f.read()
                content = content.replace('prefix = "projects/example_project"', f'prefix = "projects/{app_name}"')
                with open(backend_path, 'w') as f:
                    f.write(content)

        # Excelのセルが空(None)の場合の型安全なBoolean変換
        raw_billing = row_dict.get('billing_linked')
        is_billing_linked = False
        if raw_billing is not None and str(raw_billing).strip().lower() == 'true':
            is_billing_linked = True

        # 空セルが "None" という文字列として出力されるのを防ぐ安全な処理
        raw_env = row_dict.get('env')
        env_val = "" if raw_env is None else str(raw_env).strip()

        raw_folder_id = row_dict.get('folder_id')
        folder_id_val = "" if raw_folder_id is None else str(raw_folder_id).strip()

        # project_apis をカンマ区切りで読み込み、Terraformのリスト形式に変換
        raw_apis = row_dict.get('project_apis')
        apis_formatted = '[]'
        if raw_apis:
            apis_list = [api.strip() for api in str(raw_apis).split(',') if api.strip()]
            if apis_list:
                apis_formatted = '[\n  "' + '",\n  "'.join(apis_list) + '"\n]'

        tfvars_content = f"""# 自動生成されたファイルです。手動で編集しないでください。
organization_domain = "{domain}"
app_name            = "{app_name}"
environment         = "{env_val}"
folder_id           = "{folder_id_val}"
billing_linked      = {str(is_billing_linked).lower()}
project_apis        = {apis_formatted}
"""
        with open(os.path.join(project_dir, 'terraform.tfvars'), 'w') as f:
            f.write(tfvars_content)
    print("Successfully generated tfvars from Spreadsheet (xlsx).")
else:
    print("projects_config.xlsx not found. Skipping project tfvars generation.")
