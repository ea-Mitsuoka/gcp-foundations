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
from openpyxl import Workbook

def generate_resources():
    # 1. domainの取得
    domain_env_path = os.path.join(os.path.dirname(__file__), '../../domain.env')
    domain = ""
    if os.path.exists(domain_env_path):
        with open(domain_env_path, 'r') as f:
            for line in f:
                if line.startswith('domain='):
                    domain = line.split('=')[1].strip().strip('"')
                    break

    # 2. xlsxファイルの読み込み/作成
    xlsx_path = os.path.join(os.path.dirname(__file__), '../../gcp_foundations.xlsx')
    if not os.path.exists(xlsx_path):
        print(f"{xlsx_path} not found. Creating a template...")
        wb = Workbook()
        ws = wb.active
        ws.title = "resources"
        ws.append(["resource_type", "parent_name", "resource_name", "shared_vpc", "vpc_sc", "monitoring", "logging", "billing_linked", "project_apis"])
        ws.append(["folder", "organization_id", "shared", False, False, False, False, False, ""])
        ws.append(["folder", "shared", "production", False, False, False, False, False, ""])
        ws.append(["project", "production", "prd-app-01", True, True, True, True, True, "compute.googleapis.com,container.googleapis.com"])

        wb.save(xlsx_path)
        print("Template created! Please edit it and run this script again.")
        return

    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    if 'resources' not in wb.sheetnames:
        print("Error: 'resources' sheet not found in the spreadsheet.")
        return
    
    sheet = wb['resources']
    
    headers = [cell.value for cell in sheet[1]]
    if not headers or 'resource_type' not in headers:
        print("Error: Invalid headers in 'resources' sheet.")
        return

    folders = {}
    projects = []

    # 3. データのパース
    for row_idx, row in enumerate(sheet.iter_rows(min_row=2, values_only=True), start=2):
        if not any(row): continue
        row_dict = dict(zip(headers, row))
        
        res_type = str(row_dict.get('resource_type', '')).strip().lower()
        if res_type == 'folder':
            folders[row_dict.get('resource_name')] = row_dict.get('parent_name')
        elif res_type == 'project':
            projects.append(row_dict)

    # 4. フォルダのtfファイル生成 (3_folders/auto_folders.tf)
    folders_tf_path = os.path.join(os.path.dirname(__file__), '../3_folders/auto_folders.tf')
    with open(folders_tf_path, 'w') as f:
        f.write("# 自動生成されたファイルです。手動で編集しないでください。\n\n")
        
        for folder_name, parent_name in folders.items():
            if not folder_name: continue
            
            parent_str = str(parent_name).strip()
            if parent_str == 'organization_id':
                parent_expr = "data.google_organization.org.name"
            else:
                parent_expr = f"google_folder.{parent_str}.name"

            f.write(f'resource "google_folder" "{folder_name}" {{\n')
            f.write(f'  display_name        = "{folder_name}"\n')
            f.write(f'  parent              = {parent_expr}\n')
            f.write(f'  deletion_protection = false\n')
            f.write(f'}}\n\n')
            
            f.write(f'output "{folder_name}_folder_id" {{\n')
            f.write(f'  value = google_folder.{folder_name}.id\n')
            f.write(f'}}\n\n')

    print(f"✅ Generated auto_folders.tf in 3_folders")

    # 5. プロジェクトのtfvars生成 (4_projects/*)
    example_dir = os.path.join(os.path.dirname(__file__), '../4_projects/example_project')
    
    for proj in projects:
        app_name = proj.get('resource_name')
        if not app_name: continue
        app_name = str(app_name).strip()

        project_dir = os.path.join(os.path.dirname(__file__), f"../4_projects/{app_name}")
        
        if not os.path.exists(project_dir):
            os.makedirs(project_dir, exist_ok=True)
            for tf_file in glob.glob(os.path.join(example_dir, '*.tf')):
                shutil.copy(tf_file, project_dir)
            
            backend_path = os.path.join(project_dir, 'backend.tf')
            if os.path.exists(backend_path):
                with open(backend_path, 'r') as f:
                    content = f.read()
                content = content.replace('prefix = "projects/example_project"', f'prefix = "projects/{app_name}"')
                with open(backend_path, 'w') as f:
                    f.write(content)

        def is_true(val):
            if val is None: return False
            if isinstance(val, bool): return val
            return str(val).strip().lower() == 'true'

        parent_folder = str(proj.get('parent_name', '')).strip()
        folder_id_val = "" if parent_folder == 'organization_id' else parent_folder

        shared_vpc = is_true(proj.get('shared_vpc'))
        vpc_sc = is_true(proj.get('vpc_sc'))
        monitoring = is_true(proj.get('monitoring'))
        logging = is_true(proj.get('logging'))
        billing_linked = is_true(proj.get('billing_linked'))

        raw_apis = proj.get('project_apis')
        apis_formatted = '[]'
        if raw_apis:
            apis_list = [api.strip() for api in str(raw_apis).split(',') if api.strip()]
            if apis_list:
                apis_formatted = '[\n  "' + '",\n  "'.join(apis_list) + '"\n]'

        env_val = "prod"
        if app_name.startswith('prd-'): env_val = "prod"
        elif app_name.startswith('stg-'): env_val = "stag"
        elif app_name.startswith('dev-'): env_val = "dev"

        shared_vpc_env_val = "none"
        if shared_vpc:
            shared_vpc_env_val = "dev" if env_val == "dev" else "prod"

        tfvars_content = f"""# 自動生成されたファイルです。手動で編集しないでください。
organization_domain = "{domain}"
app_name            = "{app_name}"
environment         = "{env_val}"
folder_id           = "{folder_id_val}"
shared_vpc_env      = "{shared_vpc_env_val}"
vpc_sc              = {str(vpc_sc).lower()}
monitoring          = {str(monitoring).lower()}
logging             = {str(logging).lower()}
billing_linked      = {str(billing_linked).lower()}
project_apis        = {apis_formatted}
"""
        with open(os.path.join(project_dir, 'terraform.tfvars'), 'w') as f:
            f.write(tfvars_content)
            
    print(f"✅ Generated tfvars for projects")

if __name__ == "__main__":
    generate_resources()
