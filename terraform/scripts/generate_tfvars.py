# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "openpyxl==3.1.2",
# ]
# ///
import os
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
        os.makedirs(project_dir, exist_ok=True)
        
        tfvars_content = f"""# 自動生成されたファイルです。手動で編集しないでください。
organization_domain = "{domain}"
project_id_prefix   = "{sanitized_domain}"
+app_name            = "{app_name}"
+environment         = "{row_dict.get('env', '')}"
+folder_id           = "{row_dict.get('folder_id', '')}"
"""
        with open(os.path.join(project_dir, 'terraform.tfvars'), 'w') as f:
            f.write(tfvars_content)
    print("Successfully generated tfvars from Spreadsheet (xlsx).")
else:
    print("projects_config.xlsx not found. Skipping project tfvars generation.")
