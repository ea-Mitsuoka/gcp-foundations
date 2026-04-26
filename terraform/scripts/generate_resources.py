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
import json
from openpyxl import Workbook

def sanitize_id(name):
    """TerraformのリソースIDとして使用可能な文字列に変換する"""
    if not name: return "unknown"
    return str(name).replace("-", "_").replace(" ", "_").replace(".", "_")

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
        
        # 1. resources
        ws = wb.active
        ws.title = "resources"
        ws.append(["resource_type", "parent_name", "resource_name", "shared_vpc", "vpc_sc", "monitoring", "logging", "billing_linked", "project_apis"])
        ws.append(["folder", "organization_id", "shared", "", "", False, False, False, ""])
        ws.append(["folder", "shared", "production", "", "", False, False, False, ""])
        ws.append(["project", "production", "prd-app-01", "prd-subnet-01", "default_perimeter", True, True, True, "compute.googleapis.com,container.googleapis.com"])

        # 2. vpc_sc_perimeters
        ws2 = wb.create_sheet("vpc_sc_perimeters")
        ws2.append(["perimeter_name", "title", "restricted_services"])
        ws2.append(["default_perimeter", "Default Security Perimeter", "storage.googleapis.com,bigquery.googleapis.com,compute.googleapis.com"])

        # 3. vpc_sc_access_levels
        ws3 = wb.create_sheet("vpc_sc_access_levels")
        ws3.append(["access_level_name", "ip_subnetworks", "members"])
        ws3.append(["office_ip_only", "1.2.3.4/32", "user:admin@example.com"])

        # 4. shared_vpc_subnets
        ws4 = wb.create_sheet("shared_vpc_subnets")
        ws4.append(["host_project_env", "subnet_name", "region", "ip_cidr_range"])
        ws4.append(["prod", "prd-subnet-01", "asia-northeast1", "10.0.1.0/24"])
        ws4.append(["dev", "dev-subnet-01", "asia-northeast1", "10.1.1.0/24"])

        # 5. org_policies
        ws5 = wb.create_sheet("org_policies")
        ws5.append(["target_name", "policy_id", "enforce", "allow_list"])
        ws5.append(["organization_id", "compute.disableExternalIPProxy", True, ""])
        ws5.append(["production", "gcp.resourceLocations", True, "asia-northeast1"])

        wb.save(xlsx_path)
        print("Template created! Proceeding with initial generation...")

    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    
    # --- 欠落しているシートの自動追加 ---
    required_sheets = {
        "resources": ["resource_type", "parent_name", "resource_name", "shared_vpc", "vpc_sc", "monitoring", "logging", "billing_linked", "project_apis"],
        "vpc_sc_perimeters": ["perimeter_name", "title", "restricted_services"],
        "vpc_sc_access_levels": ["access_level_name", "ip_subnetworks", "members"],
        "shared_vpc_subnets": ["host_project_env", "subnet_name", "region", "ip_cidr_range"],
        "org_policies": ["target_name", "policy_id", "enforce", "allow_list"]
    }

    updated = False
    for sname, headers in required_sheets.items():
        if sname not in wb.sheetnames:
            print(f"Adding missing sheet: {sname}")
            ws = wb.create_sheet(sname)
            ws.append(headers)
            updated = True
    
    if updated:
        wb.save(xlsx_path)
        print(f"✅ Spreadsheet {xlsx_path} updated with missing sheets.")

    # --- データのパース ---
    
    # 1. フォルダとプロジェクト (resources)
    folders = {}
    projects = []
    if 'resources' in wb.sheetnames:
        ws = wb['resources']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            row_dict = dict(zip(headers, row))
            res_type = str(row_dict.get('resource_type', '')).strip().lower()
            if res_type == 'folder':
                folders[row_dict.get('resource_name')] = row_dict.get('parent_name')
            elif res_type == 'project':
                projects.append(row_dict)

    # 2. VPC-SC Perimeters
    perimeters = []
    if 'vpc_sc_perimeters' in wb.sheetnames:
        ws = wb['vpc_sc_perimeters']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            perimeters.append(dict(zip(headers, row)))

    # 3. VPC-SC Access Levels
    access_levels = []
    if 'vpc_sc_access_levels' in wb.sheetnames:
        ws = wb['vpc_sc_access_levels']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            access_levels.append(dict(zip(headers, row)))

    # 4. Shared VPC Subnets
    subnets = []
    if 'shared_vpc_subnets' in wb.sheetnames:
        ws = wb['shared_vpc_subnets']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            subnets.append(dict(zip(headers, row)))

    # 5. Org Policies
    org_policies = []
    if 'org_policies' in wb.sheetnames:
        ws = wb['org_policies']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            org_policies.append(dict(zip(headers, row)))

    # --- TFファイル生成 ---

    def is_true_policy(val):
        if val is None: return False
        if isinstance(val, bool): return val
        return str(val).strip().lower() == 'true'

    # 4. フォルダのtfファイル生成 (3_folders/auto_folders.tf)
    folders_tf_path = os.path.join(os.path.dirname(__file__), '../3_folders/auto_folders.tf')
    with open(folders_tf_path, 'w') as f:
        f.write("# 自動生成されたファイルです。手動で編集しないでください。\n\n")
        for folder_name, parent_name in folders.items():
            if not folder_name: continue
            fid = sanitize_id(folder_name)
            parent_str = str(parent_name).strip()
            parent_expr = "data.google_organization.org.name" if parent_str == 'organization_id' else f"google_folder.{sanitize_id(parent_str)}.name"
            f.write(f'resource "google_folder" "{fid}" {{\n')
            f.write(f'  display_name        = "{folder_name}"\n')
            f.write(f'  parent              = {parent_expr}\n')
            f.write(f'  deletion_protection = false\n')
            f.write(f'}}\n\n')
            f.write(f'output "{fid}_folder_id" {{\n  value = google_folder.{fid}.id\n}}\n\n')

    # 5. VPC-SCのtfファイル生成 (2_organization/auto_vpc_sc.tf)
    vpc_sc_tf_path = os.path.join(os.path.dirname(__file__), '../2_organization/auto_vpc_sc.tf')
    with open(vpc_sc_tf_path, 'w') as f:
        f.write("# 自動生成されたファイルです。手動で編集しないでください。\n\n")
        access_level_ids = {}
        for al in access_levels:
            name = al.get('access_level_name')
            if not name: continue
            sid = sanitize_id(name)
            f.write(f'resource "google_access_context_manager_access_level" "{sid}" {{\n')
            f.write(f'  parent = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}"\n')
            f.write(f'  name   = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}/accessLevels/{name}"\n')
            f.write(f'  title  = "{name}"\n')
            f.write(f'  basic {{\n    conditions {{\n')
            if al.get('ip_subnetworks'):
                ips = [ip.strip() for ip in str(al['ip_subnetworks']).split(',') if ip.strip()]
                f.write(f'      ip_subnetworks = {json.dumps(ips)}\n')
            if al.get('members'):
                members = [m.strip() for m in str(al['members']).split(',') if m.strip()]
                f.write(f'      members = {json.dumps(members)}\n')
            f.write(f'    }}\n  }}\n}}\n\n')
            access_level_ids[name] = f"google_access_context_manager_access_level.{sid}.name"

        perimeter_ids = {}
        for p in perimeters:
            name = p.get('perimeter_name')
            if not name: continue
            sid = sanitize_id(name)
            services = [s.strip() for s in str(p.get('restricted_services', '')).split(',') if s.strip()]
            f.write(f'resource "google_access_context_manager_service_perimeter" "{sid}" {{\n')
            f.write(f'  parent = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}"\n')
            f.write(f'  name   = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}/servicePerimeters/{name}"\n')
            f.write(f'  title  = "{name}"\n')
            f.write(f'  status {{\n')
            f.write(f'    restricted_services = {json.dumps(services)}\n')
            f.write(f'  }}\n')
            f.write(f'  lifecycle {{\n    ignore_changes = [status[0].resources]\n  }}\n}}\n\n')
            perimeter_ids[name] = f"google_access_context_manager_service_perimeter.{sid}.name"

        f.write(f'output "service_perimeter_ids" {{\n  value = {{\n')
        for k, v in perimeter_ids.items(): f.write(f'    "{k}" = {v}\n')
        f.write(f'  }}\n}}\n\n')
        f.write(f'output "access_level_ids" {{\n  value = {{\n')
        for k, v in access_level_ids.items(): f.write(f'    "{k}" = {v}\n')
        f.write(f'  }}\n}}\n\n')

    # 6. Shared VPC Subnetsのtfファイル生成 (1_core/base/vpc-host/auto_subnets.tf)
    subnets_tf_path = os.path.join(os.path.dirname(__file__), '../1_core/base/vpc-host/auto_subnets.tf')
    with open(subnets_tf_path, 'w') as f:
        f.write("# 自動生成されたファイルです。手動で編集しないでください。\n\n")
        subnet_ids = {}
        for sn in subnets:
            env = str(sn.get('host_project_env', '')).strip().lower()
            name = sn.get('subnet_name')
            if not name or env not in ['prod', 'dev']: continue
            sid = sanitize_id(name)
            module_name = f"vpc_host_{env}"
            f.write(f'resource "google_compute_subnetwork" "{sid}" {{\n')
            f.write(f'  name          = "{name}"\n')
            f.write(f'  ip_cidr_range = "{sn.get("ip_cidr_range")}"\n')
            f.write(f'  region        = "{sn.get("region")}"\n')
            f.write(f'  network       = google_compute_network.vpc_{env}[0].id\n')
            f.write(f'  project       = module.{module_name}[0].project_id\n')
            f.write(f'  private_ip_google_access = true\n')
            f.write(f'}}\n\n')
            subnet_ids[name] = f"google_compute_subnetwork.{sid}.id"
        
        f.write(f'output "shared_vpc_subnet_ids" {{\n  value = {{\n')
        for k, v in subnet_ids.items(): f.write(f'    "{k}" = {v}\n')
        f.write(f'  }}\n}}\n\n')

    # 7. 組織ポリシーの生成 (各レイヤー)
    # 2_organization/auto_org_policies.tf
    org_policy_path = os.path.join(os.path.dirname(__file__), '../2_organization/auto_org_policies.tf')
    with open(org_policy_path, 'w') as f:
        f.write("# 自動生成されたファイルです。手動で編集しないでください。\n\n")
        for p in org_policies:
            if p.get('target_name') != 'organization_id': continue
            pid = p.get('policy_id')
            sid = sanitize_id(pid)
            enforce = is_true_policy(p.get('enforce'))
            f.write(f'resource "google_org_policy_policy" "{sid}" {{\n')
            f.write(f'  count  = var.enable_org_policies ? 1 : 0\n')
            f.write(f'  name   = "organizations/${{data.google_organization.org.org_id}}/policies/{pid}"\n')
            f.write(f'  parent = "organizations/${{data.google_organization.org.org_id}}"\n')
            f.write(f'  spec {{\n')
            if p.get('allow_list'):
                f.write(f'    rules {{\n      values {{\n')
                f.write(f'        allowed_values = {json.dumps([v.strip() for v in str(p["allow_list"]).split(",")])}\n')
                f.write(f'      }}\n    }}\n')
            else:
                f.write(f'    rules {{\n      enforce = "{str(enforce).lower()}"\n    }}\n')
            f.write(f'  }}\n}}\n\n')

    # 3_folders/auto_org_policies.tf
    folder_policy_path = os.path.join(os.path.dirname(__file__), '../3_folders/auto_org_policies.tf')
    with open(folder_policy_path, 'w') as f:
        f.write("# 自動生成されたファイルです。手動で編集しないでください。\n\n")
        for p in org_policies:
            target = p.get('target_name')
            if target == 'organization_id' or target not in folders: continue
            pid = p.get('policy_id')
            sid = sanitize_id(f"{target}_{pid}")
            enforce = is_true_policy(p.get('enforce'))
            f.write(f'resource "google_org_policy_policy" "{sid}" {{\n')
            f.write(f'  count  = var.enable_org_policies ? 1 : 0\n')
            f.write(f'  name   = "folders/${{google_folder.{sanitize_id(target)}.name}}/policies/{pid}"\n')
            f.write(f'  parent = "folders/${{google_folder.{sanitize_id(target)}.name}}"\n')
            f.write(f'  spec {{\n')
            if p.get('allow_list'):
                f.write(f'    rules {{\n      values {{\n')
                f.write(f'        allowed_values = {json.dumps([v.strip() for v in str(p["allow_list"]).split(",")])}\n')
                f.write(f'      }}\n    }}\n')
            else:
                f.write(f'    rules {{\n      enforce = "{str(enforce).lower()}"\n    }}\n')
            f.write(f'  }}\n}}\n\n')

    # 8. プロジェクトのtfvars生成 (4_projects/*)
    example_dir = os.path.join(os.path.dirname(__file__), '../4_projects/example_project')
    
    for proj in projects:
        app_name = proj.get('resource_name')
        if not app_name: continue
        app_name = str(app_name).strip()

        project_dir = os.path.join(os.path.dirname(__file__), f"../4_projects/{app_name}")
        os.makedirs(project_dir, exist_ok=True)

        # プロジェクト用の auto_org_policies.tf 生成
        with open(os.path.join(project_dir, 'auto_org_policies.tf'), 'w') as f:
            f.write("# 自動生成されたファイルです。手動で編集しないでください。\n\n")
            for p in org_policies:
                if p.get('target_name') != app_name: continue
                pid = p.get('policy_id')
                sid = sanitize_id(pid)
                enforce = is_true_policy(p.get('enforce'))
                f.write(f'resource "google_org_policy_policy" "{sid}" {{\n')
                f.write(f'  count  = var.enable_org_policies ? 1 : 0\n')
                f.write(f'  name   = "projects/${{module.project.project_id}}/policies/{pid}"\n')
                f.write(f'  parent = "projects/${{module.project.project_id}}"\n')
                f.write(f'  spec {{\n')
                if p.get('allow_list'):
                    f.write(f'    rules {{\n      values {{\n')
                    f.write(f'        allowed_values = {json.dumps([v.strip() for v in str(p["allow_list"]).split(",")])}\n')
                    f.write(f'      }}\n    }}\n')
                else:
                    f.write(f'    rules {{\n      enforce = "{str(enforce).lower()}"\n    }}\n')
                f.write(f'  }}\n}}\n\n')

        # 既存ファイルのコピーとbackend修正 (初回のみ)
        for tf_file in glob.glob(os.path.join(example_dir, '*.tf')):
            target_file = os.path.join(project_dir, os.path.basename(tf_file))
            if not os.path.exists(target_file):
                shutil.copy(tf_file, project_dir)
                if os.path.basename(tf_file) == 'backend.tf':
                    with open(target_file, 'r') as f:
                        content = f.read()
                    content = content.replace('prefix = "projects/example_project"', f'prefix = "projects/{app_name}"')
                    with open(target_file, 'w') as f:
                        f.write(content)

        def is_true(val):
            if val is None: return False
            if isinstance(val, bool): return val
            return str(val).strip().lower() == 'true'

        parent_folder = str(proj.get('parent_name', '')).strip()
        folder_id_val = "" if parent_folder == 'organization_id' else parent_folder

        vpc_sc_val = str(proj.get('vpc_sc', '')).strip()
        if vpc_sc_val.lower() in ['false', 'none', '']: vpc_sc_val = ""
        
        shared_vpc_sn_val = str(proj.get('shared_vpc', '')).strip()
        if shared_vpc_sn_val.lower() in ['false', 'none', '']: shared_vpc_sn_val = ""

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
        if shared_vpc_sn_val:
            shared_vpc_env_val = "dev" if env_val == "dev" else "prod"

        tfvars_content = f"""# 自動生成されたファイルです。手動で編集しないでください。
organization_domain = "{domain}"
app_name            = "{app_name}"
environment         = "{env_val}"
folder_id           = "{folder_id_val}"
shared_vpc_env      = "{shared_vpc_env_val}"
shared_vpc_subnet   = "{shared_vpc_sn_val}"
vpc_sc              = "{vpc_sc_val}"
monitoring          = {str(monitoring).lower()}
logging             = {str(logging).lower()}
billing_linked      = {str(billing_linked).lower()}
project_apis        = {apis_formatted}
"""
        with open(os.path.join(project_dir, 'terraform.tfvars'), 'w') as f:
            f.write(tfvars_content)
            
    print(f"✅ Generated tfvars and auto_org_policies.tf for all layers")

if __name__ == "__main__":
    generate_resources()
