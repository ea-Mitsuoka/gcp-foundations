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
import sys
import re
import ipaddress
from openpyxl import Workbook
from openpyxl.worksheet.datavalidation import DataValidation

import csv

def sanitize_id(name):
    """TerraformのリソースIDとして使用可能な文字列に変換する"""
    if not name: return "unknown"
    return str(name).replace("-", "_").replace(" ", "_").replace(".", "_")

def validate_gcp_resource_name(name, resource_type, row_idx):
    """GCPのリソース命名規則に沿っているか検証する"""
    if not name: return f"行 {row_idx}: リソース名が空です。"
    
    # プロジェクトID: 6-30文字、小文字、数字、ハイフン、先頭は英字、末尾は英数字
    if resource_type == 'project':
        if not re.match(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$', name):
            return f"行 {row_idx}: プロジェクト名 '{name}' が不正です (6-30文字, 小文字, 数字, ハイフン, 先頭英字, 末尾英数字のみ)。"
    # フォルダ名: 1-30文字、英数字、ハイフン、スペース
    elif resource_type == 'folder':
        if not re.match(r'^[a-zA-Z0-9- ]{1,30}$', name):
            return f"行 {row_idx}: フォルダ名 '{name}' が不正です (1-30文字, 英数字, ハイフン, スペースのみ)。"
    return None

def add_validation(ws, col_letter, formula, title, prompt):
    """Excelシートにデータ入力規則（プルダウン）を追加する"""
    dv = DataValidation(type="list", formula1=formula, allow_blank=True)
    dv.errorTitle = "入力エラー"
    dv.error = f"{title}の選択肢から選んでください。"
    dv.promptTitle = title
    dv.prompt = prompt
    ws.add_data_validation(dv)
    # 2行目から100行目まで適用
    dv.add(f"{col_letter}2:{col_letter}100")

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
    xlsx_path = os.path.join(os.path.dirname(__file__), '../../gcp-foundations.xlsx')
    if not os.path.exists(xlsx_path):
        print(f"{xlsx_path} not found. Creating a template with data validation...")
        wb = Workbook()
        
        # 1. resources
        ws = wb.active
        ws.title = "resources"
        headers = ["resource_type", "parent_name", "resource_name", "owner", "shared_vpc", "vpc_sc", "monitoring", "logging"]
        ws.append(headers)
        ws.append(["folder", "organization_id", "shared", "admin@example.com", "", "", False, False])
        ws.append(["folder", "shared", "production", "admin@example.com", "", "", False, False])
        ws.append(["project", "production", "prd-app-01", "app-team@example.com", "prd-subnet-01", "default_perimeter", True, True])

        # 入力規則の追加
        add_validation(ws, "A", '"folder,project"', "リソースタイプ", "リソースの種別を選択")
        add_validation(ws, "F", '"True,False"', "モニタリング", "有効にする場合はTrue")
        add_validation(ws, "G", '"True,False"', "ロギング", "有効にする場合はTrue")

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
        add_validation(ws4, "A", '"prod,dev"', "環境", "本番(prod)か開発(dev)かを選択")

        # 5. org_policies
        ws5 = wb.create_sheet("org_policies")
        ws5.append(["target_name", "policy_id", "enforce", "allow_list"])
        ws5.append(["organization_id", "compute.disableExternalIPProxy", True, ""])
        ws5.append(["production", "gcp.resourceLocations", True, "asia-northeast1"])
        add_validation(ws5, "C", '"True,False"', "強制", "ポリシーを強制するか")

        # 6. notifications
        ws6 = wb.create_sheet("notifications")
        ws6.append(["alert_name", "user_email", "receive_alerts"])
        ws6.append(["error_log_alert", "admin@example.com", True])

        # 7. alert_definitions
        ws7 = wb.create_sheet("alert_definitions")
        ws7.append(["alert_name", "alert_display_name", "metric_filter", "alert_documentation"])
        ws7.append(["error_log_alert", "Error Log Alert", 'severity="ERROR"', "Documentation for error log alert"])

        # 8. log_sinks
        ws8 = wb.create_sheet("log_sinks")
        ws8.append(["log_type", "filter", "destination_type", "destination_parent", "retention_days"])
        ws8.append(["管理アクティビティ監査ログ", "protoPayload.methodName:*", "BigQuery", "audit_logs", 365])
        add_validation(ws8, "C", '"BigQuery,Cloud Storage"', "宛先タイプ", "出力先の種別を選択")

        wb.save(xlsx_path)
        print("Template created! Proceeding with initial generation...")

    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    
    # --- 欠落しているシートの自動追加 ---
    required_sheets = {
        "resources": ["resource_type", "parent_name", "resource_name", "owner", "shared_vpc", "vpc_sc", "monitoring", "logging"],
        "vpc_sc_perimeters": ["perimeter_name", "title", "restricted_services"],
        "vpc_sc_access_levels": ["access_level_name", "ip_subnetworks", "members"],
        "shared_vpc_subnets": ["host_project_env", "subnet_name", "region", "ip_cidr_range"],
        "org_policies": ["target_name", "policy_id", "enforce", "allow_list"],
        "notifications": ["alert_name", "user_email", "receive_alerts"],
        "alert_definitions": ["alert_name", "alert_display_name", "metric_filter", "alert_documentation"],
        "log_sinks": ["log_type", "filter", "destination_type", "destination_parent", "retention_days"]
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

    # --- データのパースとバリデーション ---
    errors = []
    
    def validate_row(row_dict, required_keys, sheet_name, row_idx):
        for key in required_keys:
            if not row_dict.get(key):
                errors.append(f"[{sheet_name}] {row_idx}行目: 必須項目 '{key}' が空です。")

    # --- データの読み込み ---
    # 2. VPC-SC Perimeters
    perimeters = []
    valid_perimeters = set()
    if 'vpc_sc_perimeters' in wb.sheetnames:
        ws = wb['vpc_sc_perimeters']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            p_dict = dict(zip(headers, [v if not (isinstance(v, float) and v.is_integer()) else str(int(v)) for v in row]))
            perimeters.append(p_dict)
            if p_dict.get('perimeter_name'):
                valid_perimeters.add(str(p_dict['perimeter_name']).strip())

    # 3. VPC-SC Access Levels
    access_levels = []
    if 'vpc_sc_access_levels' in wb.sheetnames:
        ws = wb['vpc_sc_access_levels']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            access_levels.append(dict(zip(headers, [v if not (isinstance(v, float) and v.is_integer()) else str(int(v)) for v in row])))

    # 4. Shared VPC Subnets
    subnets = []
    valid_subnets = set()
    used_cidrs = []
    if 'shared_vpc_subnets' in wb.sheetnames:
        ws = wb['shared_vpc_subnets']
        headers = [cell.value for cell in ws[1]]
        for idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
            if not any(row): continue
            s_dict = dict(zip(headers, [v if not (isinstance(v, float) and v.is_integer()) else str(int(v)) for v in row]))
            subnets.append(s_dict)
            
            s_name = str(s_dict.get('subnet_name', '')).strip()
            if s_name: valid_subnets.add(s_name)
            
            cidr = str(s_dict.get('ip_cidr_range', '')).strip()
            if cidr:
                try:
                    new_net = ipaddress.ip_network(cidr, strict=True)
                    for old_net in used_cidrs:
                        if new_net.overlaps(old_net):
                            errors.append(f"[shared_vpc_subnets] {idx}行目: CIDR '{cidr}' が '{old_net}' と重複しています。")
                    used_cidrs.append(new_net)
                except ValueError as e:
                    errors.append(f"[shared_vpc_subnets] {idx}行目: 不正な CIDR 形式またはネットワークアドレスです '{cidr}' ({e})。")

    # 1. フォルダとプロジェクト (resources) の読み込み
    all_resource_names = set() 
    folders = {}
    projects = []
    if 'resources' in wb.sheetnames:
        ws = wb['resources']
        headers = [cell.value for cell in ws[1]]
        for idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
            if not any(row): continue
            row_dict = dict(zip(headers, [v if not (isinstance(v, float) and v.is_integer()) else str(int(v)) for v in row]))
            # owner も必須チェックに含める
            validate_row(row_dict, ['resource_type', 'parent_name', 'resource_name', 'owner'], 'resources', idx)
            
            res_name = str(row_dict.get('resource_name', '')).strip()
            res_type = str(row_dict.get('resource_type', '')).strip().lower()
            parent_name = str(row_dict.get('parent_name', '')).strip()
            shared_vpc = str(row_dict.get('shared_vpc', '')).strip()
            vpc_sc = str(row_dict.get('vpc_sc', '')).strip()

            # 命名規則チェック
            name_error = validate_gcp_resource_name(res_name, res_type, idx)
            if name_error: errors.append(f"[resources] {name_error}")

            if res_name in all_resource_names:
                errors.append(f"[resources] {idx}行目: リソース名 '{res_name}' が重複しています。")
            all_resource_names.add(res_name)

            if res_type not in ['folder', 'project']:
                errors.append(f"[resources] {idx}行目: 不正な resource_type '{res_type}' です。'folder' または 'project' を指定してください。")
            
            # 循環参照チェック
            if res_name == parent_name:
                errors.append(f"[resources] {idx}行目: 自分自身 '{res_name}' を親に指定することはできません (循環参照)。")

            # 整合性チェック: Shared VPC Subnet
            if res_type == 'project' and shared_vpc and shared_vpc.lower() not in ['false', 'none', '']:
                if shared_vpc not in valid_subnets:
                    errors.append(f"[resources] {idx}行目: 指定された Shared VPC サブネット '{shared_vpc}' は 'shared_vpc_subnets' シートに定義されていません。")

            # 整合性チェック: VPC-SC Perimeter
            if res_type == 'project' and vpc_sc and vpc_sc.lower() not in ['false', 'none', '']:
                if vpc_sc not in valid_perimeters:
                    errors.append(f"[resources] {idx}行目: 指定された VPC-SC 境界 '{vpc_sc}' は 'vpc_sc_perimeters' シートに定義されていません。")

            if res_type == 'folder':
                folders[res_name] = parent_name
            elif res_type == 'project':
                projects.append(row_dict)

        # 親リソースの存在確認 (フォルダ)
        for name, parent in folders.items():
            if parent != 'organization_id' and parent not in folders:
                errors.append(f"[resources] フォルダ '{name}' の親 '{parent}' が resources シート内に定義されていません。")
        
        # 親リソースの存在確認 (プロジェクト)
        for proj in projects:
            parent = str(proj.get('parent_name', '')).strip()
            name = str(proj.get('resource_name', '')).strip()
            if parent != 'organization_id' and parent not in folders:
                errors.append(f"[resources] プロジェクト '{name}' の親フォルダ '{parent}' が resources シート内に定義されていません。")

    # 5. Org Policies
    org_policies = []
    if 'org_policies' in wb.sheetnames:
        ws = wb['org_policies']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            org_policies.append(dict(zip(headers, [v if not (isinstance(v, float) and v.is_integer()) else str(int(v)) for v in row])))

    # 7. Alert Definitions
    alert_definitions = []
    valid_alert_names = set()
    if 'alert_definitions' in wb.sheetnames:
        ws = wb['alert_definitions']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            d_dict = dict(zip(headers, [v if not (isinstance(v, float) and v.is_integer()) else str(int(v)) for v in row]))
            alert_definitions.append(d_dict)
            if d_dict.get('alert_name'):
                valid_alert_names.add(str(d_dict['alert_name']).strip())

    # 6. Notifications
    if 'notifications' in wb.sheetnames:
        ws = wb['notifications']
        headers = [cell.value for cell in ws[1]]
        for idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
            if not any(row): continue
            row_dict = dict(zip(headers, [v if not (isinstance(v, float) and v.is_integer()) else str(int(v)) for v in row]))
            alert_name = str(row_dict.get('alert_name', '')).strip()
            
            if alert_name and alert_name not in valid_alert_names:
                errors.append(f"[notifications] {idx}行目: アラート名 '{alert_name}' は 'alert_definitions' シートに定義されていません。")

    # --- バリデーションエラーがあれば停止 ---
    if errors:
        print("\n❌ 構成エラーを検知しました:")
        for err in errors:
            print(f"  - {err}")
        print("\n修正後に再度 'make generate' を実行してください。")
        sys.exit(1)

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
            f.write(f'  count  = var.enable_vpc_sc ? 1 : 0\n')
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
            access_level_ids[name] = f"var.enable_vpc_sc ? google_access_context_manager_access_level.{sid}[0].name : null"

        perimeter_ids = {}
        for p in perimeters:
            name = p.get('perimeter_name')
            if not name: continue
            sid = sanitize_id(name)
            services = [s.strip() for s in str(p.get('restricted_services', '')).split(',') if s.strip()]
            f.write(f'resource "google_access_context_manager_service_perimeter" "{sid}" {{\n')
            f.write(f'  count  = var.enable_vpc_sc ? 1 : 0\n')
            f.write(f'  parent = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}"\n')
            f.write(f'  name   = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}/servicePerimeters/{name}"\n')
            f.write(f'  title  = "{name}"\n')
            f.write(f'  status {{\n')
            f.write(f'    restricted_services = {json.dumps(services)}\n')
            f.write(f'  }}\n')
            f.write(f'  lifecycle {{\n    ignore_changes = [status[0].resources]\n  }}\n}}\n\n')
            perimeter_ids[name] = f"var.enable_vpc_sc ? google_access_context_manager_service_perimeter.{sid}[0].name : null"

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
                f.write(f'    rules {{\n      deny_all = "true"\n    }}\n')
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
                f.write(f'    rules {{\n      deny_all = "true"\n    }}\n')
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

        env_val = "prod"
        if app_name.startswith('prd-'): env_val = "prod"
        elif app_name.startswith('stg-'): env_val = "stag"
        elif app_name.startswith('dev-'): env_val = "dev"

        shared_vpc_env_val = "none"
        if shared_vpc_sn_val:
            shared_vpc_env_val = "dev" if env_val == "dev" else "prod"

        owner_val = str(proj.get('owner', 'unknown')).strip()

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
deletion_protection = true

labels = {{
  env     = "{env_val}"
  owner   = "{owner_val}"
  app     = "{app_name}"
}}
"""
        with open(os.path.join(project_dir, 'terraform.tfvars'), 'w') as f:
            f.write(tfvars_content)
            
    # 9. Monitoring CSV generation
    def export_to_csv(sheet_name, target_paths):
        if sheet_name in wb.sheetnames:
            ws = wb[sheet_name]
            # Noneでないヘッダーのみを取得
            headers = [cell.value for cell in ws[1] if cell.value is not None]
            rows = []
            for row in ws.iter_rows(min_row=2, values_only=True):
                if not any(row): continue
                # ヘッダーの数に合わせてデータ行をスライスし、型変換を行う
                row_values = [v if not (isinstance(v, float) and v.is_integer()) else str(int(v)) for v in row[:len(headers)]]
                rows.append(dict(zip(headers, row_values)))
            
            if headers:
                for path in target_paths:
                    full_path = os.path.join(os.path.dirname(__file__), path)
                    os.makedirs(os.path.dirname(full_path), exist_ok=True)
                    with open(full_path, 'w', newline='', encoding='utf-8') as f:
                        writer = csv.DictWriter(f, fieldnames=headers)
                        writer.writeheader()
                        if rows:
                            writer.writerows(rows)
                    print(f"✅ Generated {full_path}")

    export_to_csv("notifications", [
        '../1_core/services/monitoring/1_notification_channels/notifications.csv',
        '../1_core/services/monitoring/2_alert_policies/logsink_log_alerts/notifications.csv'
    ])
    export_to_csv("alert_definitions", [
        '../1_core/services/monitoring/2_alert_policies/logsink_log_alerts/alert_definitions.csv'
    ])
    export_to_csv("log_sinks", [
        '../1_core/services/logsink/sinks/gcp_log_sink_config.csv'
    ])

    print(f"✅ Generated tfvars and auto_org_policies.tf for all layers")

if __name__ == "__main__":
    generate_resources()
