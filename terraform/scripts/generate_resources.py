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

# --- Validation Logic (Extracted for Testing) ---

class ResourceValidator:
    @staticmethod
    def validate_gcp_resource_name(name, resource_type):
        """Validates if a GCP resource name follows the naming conventions."""
        if not name:
            return "Resource name is empty."
        
        name = str(name).strip()
        # Project ID: 6-30 chars, lowercase, numbers, hyphens, starts with letter, ends with alphanumeric
        if resource_type == 'project':
            if not re.match(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$', name):
                return f"Project name '{name}' is invalid (6-30 chars, lowercase, numbers, hyphens, starts with letter, ends with alphanumeric)."
        # Folder Name: 1-30 chars, alphanumeric, hyphens, spaces
        elif resource_type == 'folder':
            if not re.match(r'^[a-zA-Z0-9- ]{1,30}$', name):
                return f"Folder name '{name}' is invalid (1-30 chars, alphanumeric, hyphens, spaces only)."
        return None

    @staticmethod
    def validate_cidr(cidr, used_cidrs):
        """Validates CIDR format and overlaps."""
        if not cidr:
            return None
        try:
            new_net = ipaddress.ip_network(cidr, strict=True)
            for old_net in used_cidrs:
                if new_net.overlaps(old_net):
                    return f"CIDR '{cidr}' overlaps with '{old_net}'."
            return None
        except ValueError as e:
            return f"Invalid CIDR format or network address: '{cidr}' ({e})."

    @staticmethod
    def validate_hierarchy(resources):
        """Validates hierarchy for circular references and missing parents."""
        errors = []
        # resources is a list of dicts with 'resource_name', 'resource_type', 'parent_name'
        folders = {str(r['resource_name']).strip() for r in resources if str(r['resource_type']).strip().lower() == 'folder'}
        
        for r in resources:
            name = str(r['resource_name']).strip()
            parent = str(r['parent_name']).strip()
            res_type = str(r['resource_type']).strip().lower()

            if name == parent:
                errors.append(f"Resource '{name}' cannot have itself as a parent (circular reference).")
            
            if parent != 'organization_id' and parent not in folders:
                errors.append(f"{res_type.capitalize()} '{name}' refers to parent '{parent}' which is not defined in the resources sheet.")
        
        return errors

# --- Helper functions ---

def sanitize_id(name):
    """Converts a string to a valid Terraform resource ID."""
    if not name: return "unknown"
    return str(name).replace("-", "_").replace(" ", "_").replace(".", "_")

def add_validation(ws, col_letter, formula, title, prompt):
    """Adds data validation (dropdown) to an Excel sheet."""
    dv = DataValidation(type="list", formula1=formula, allow_blank=True)
    dv.errorTitle = "Input Error"
    dv.error = f"Please select from the options in {title}."
    dv.promptTitle = title
    dv.prompt = prompt
    ws.add_data_validation(dv)
    dv.add(f"{col_letter}2:{col_letter}100")

def generate_resources():
    # 1. domain and mgmt project extraction
    domain_env_path = os.path.join(os.path.dirname(__file__), '../../domain.env')
    domain = ""
    if os.path.exists(domain_env_path):
        with open(domain_env_path, 'r') as f:
            for line in f:
                if line.startswith('domain='):
                    domain = line.split('=')[1].strip().strip('"')
                    break

    # Extract Management Project ID from bootstrap tfvars
    mgmt_project_id = ""
    bootstrap_vars_path = os.path.join(os.path.dirname(__file__), '../0_bootstrap/terraform.tfvars')
    if os.path.exists(bootstrap_vars_path):
        with open(bootstrap_vars_path, 'r') as f:
            for line in f:
                if 'project_id' in line:
                    mgmt_project_id = line.split('=')[1].strip().strip('"')

    # 2. xlsx loading/creation
    xlsx_path = os.path.join(os.path.dirname(__file__), '../../gcp-foundations.xlsx')
    if not os.path.exists(xlsx_path):
        print(f"{xlsx_path} not found. Creating a template with data validation...")
        wb = Workbook()
        
        # 1. resources
        ws = wb.active
        ws.title = "resources"
        headers = ["resource_type", "parent_name", "resource_name", "owner", "budget_amount", "budget_alert_emails", "shared_vpc", "vpc_sc", "monitoring", "logging"]
        ws.append(headers)
        ws.append(["folder", "organization_id", "shared", "admin@example.com", 0, "", "", "", False, False])
        ws.append(["folder", "shared", "production", "admin@example.com", 0, "", "", "", False, False])
        ws.append(["project", "production", "prd-app-01", "app-team@example.com", 1000, "finance@example.com,lead@example.com", "prd-subnet-01", "default_perimeter", True, True])

        add_validation(ws, "A", '"folder,project"', "Resource Type", "Select type of resource")
        add_validation(ws, "I", '"True,False"', "Monitoring", "Set True to enable")
        add_validation(ws, "J", '"True,False"', "Logging", "Set True to enable")

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
        add_validation(ws4, "A", '"prod,dev"', "Environment", "Select prod or dev")

        # 5. org_policies
        ws5 = wb.create_sheet("org_policies")
        ws5.append(["target_name", "policy_id", "enforce", "allow_list"])
        ws5.append(["organization_id", "compute.disableExternalIPProxy", True, ""])
        ws5.append(["production", "gcp.resourceLocations", True, "asia-northeast1"])
        add_validation(ws5, "C", '"True,False"', "Enforce", "Enforce policy?")

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
        add_validation(ws8, "C", '"BigQuery,Cloud Storage"', "Destination Type", "Select destination type")

        wb.save(xlsx_path)
        print("Template created! Proceeding with initial generation...")

    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    
    # --- Auto-add missing sheets ---
    required_sheets = {
        "resources": ["resource_type", "parent_name", "resource_name", "owner", "budget_amount", "budget_alert_emails", "shared_vpc", "vpc_sc", "monitoring", "logging"],
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

    # --- Parsing and Validation ---
    errors = []
    validator = ResourceValidator()
    
    def validate_row(row_dict, required_keys, sheet_name, row_idx):
        for key in required_keys:
            if row_dict.get(key) is None:
                errors.append(f"[{sheet_name}] Row {row_idx}: Required field '{key}' is empty.")

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
                cidr_err = validator.validate_cidr(cidr, used_cidrs)
                if cidr_err:
                    errors.append(f"[shared_vpc_subnets] Row {idx}: {cidr_err}")
                else:
                    try:
                        used_cidrs.append(ipaddress.ip_network(cidr, strict=True))
                    except ValueError: pass # already reported

    # 1. Folders and Projects (resources)
    all_resource_names = set() 
    folders = {}
    projects = []
    resources_data = []
    if 'resources' in wb.sheetnames:
        ws = wb['resources']
        headers = [cell.value for cell in ws[1]]
        for idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
            if not any(row): continue
            row_dict = dict(zip(headers, [v if not (isinstance(v, float) and v.is_integer()) else str(int(v)) for v in row]))
            resources_data.append(row_dict)
            validate_row(row_dict, ['resource_type', 'parent_name', 'resource_name', 'owner'], 'resources', idx)
            
            res_name = str(row_dict.get('resource_name', '')).strip()
            res_type = str(row_dict.get('resource_type', '')).strip().lower()
            shared_vpc = str(row_dict.get('shared_vpc', '')).strip()
            vpc_sc = str(row_dict.get('vpc_sc', '')).strip()

            name_err = validator.validate_gcp_resource_name(res_name, res_type)
            if name_err: errors.append(f"[resources] Row {idx}: {name_err}")

            if res_name in all_resource_names:
                errors.append(f"[resources] Row {idx}: Resource name '{res_name}' is duplicated.")
            all_resource_names.add(res_name)

            if res_type not in ['folder', 'project']:
                errors.append(f"[resources] Row {idx}: Invalid resource_type '{res_type}'. Use 'folder' or 'project'.")
            
            if res_type == 'project' and shared_vpc and shared_vpc.lower() not in ['false', 'none', '']:
                if shared_vpc not in valid_subnets:
                    errors.append(f"[resources] Row {idx}: Shared VPC subnet '{shared_vpc}' is not defined in 'shared_vpc_subnets' sheet.")

            if res_type == 'project' and vpc_sc and vpc_sc.lower() not in ['false', 'none', '']:
                if vpc_sc not in valid_perimeters:
                    errors.append(f"[resources] Row {idx}: VPC-SC perimeter '{vpc_sc}' is not defined in 'vpc_sc_perimeters' sheet.")

            if res_type == 'folder':
                folders[res_name] = str(row_dict.get('parent_name', '')).strip()
            elif res_type == 'project':
                projects.append(row_dict)

        hierarchy_errors = validator.validate_hierarchy(resources_data)
        for h_err in hierarchy_errors:
            errors.append(f"[resources] {h_err}")

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
                errors.append(f"[notifications] Row {idx}: Alert name '{alert_name}' is not defined in 'alert_definitions' sheet.")

    if errors:
        print("\n❌ Configuration errors detected:")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)

    # --- TF File Generation ---

    def is_true_policy(val):
        if val is None: return False
        if isinstance(val, bool): return val
        return str(val).strip().lower() == 'true'

    # 4. Folders (3_folders/auto_folders.tf)
    folders_tf_path = os.path.join(os.path.dirname(__file__), '../3_folders/auto_folders.tf')
    with open(folders_tf_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.\n\n")
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

    # 5. VPC-SC (2_organization/auto_vpc_sc.tf)
    vpc_sc_tf_path = os.path.join(os.path.dirname(__file__), '../2_organization/auto_vpc_sc.tf')
    with open(vpc_sc_tf_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.\n\n")
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

    # 6. Shared VPC Subnets (1_core/base/vpc-host/auto_subnets.tf)
    subnets_tf_path = os.path.join(os.path.dirname(__file__), '../1_core/base/vpc-host/auto_subnets.tf')
    with open(subnets_tf_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.\n\n")
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

    # 7. Org Policies
    # 2_organization
    org_policy_path = os.path.join(os.path.dirname(__file__), '../2_organization/auto_org_policies.tf')
    with open(org_policy_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.\n\n")
        for p in org_policies:
            if p.get('target_name') != 'organization_id': continue
            pid = p.get('policy_id')
            sid = sanitize_id(pid)
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

    # 3_folders
    folder_policy_path = os.path.join(os.path.dirname(__file__), '../3_folders/auto_org_policies.tf')
    with open(folder_policy_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.\n\n")
        for p in org_policies:
            target = p.get('target_name')
            if target == 'organization_id' or target not in folders: continue
            pid = p.get('policy_id')
            sid = sanitize_id(f"{target}_{pid}")
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

    # 8. Projects (4_projects/*)
    example_dir = os.path.join(os.path.dirname(__file__), '../4_projects/example_project')
    for proj in projects:
        app_name = str(proj.get('resource_name', '')).strip()
        if not app_name: continue
        project_dir = os.path.join(os.path.dirname(__file__), f"../4_projects/{app_name}")
        os.makedirs(project_dir, exist_ok=True)

        with open(os.path.join(project_dir, 'auto_org_policies.tf'), 'w') as f:
            f.write("# Auto-generated file. Do not edit manually.\n\n")
            for p in org_policies:
                if p.get('target_name') != app_name: continue
                pid = p.get('policy_id')
                sid = sanitize_id(pid)
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
                    f.write(f'    rules {{\n      deny_all = "true"\n    }}\n')
                f.write(f'  }}\n}}\n\n')

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
        
        # Budget settings
        budget_amount = proj.get('budget_amount', 0)
        if budget_amount is None: budget_amount = 0
        
        budget_emails_raw = str(proj.get('budget_alert_emails', '')).strip()
        budget_emails = [e.strip() for e in budget_emails_raw.split(',') if e.strip()]

        env_val = "prod"
        if app_name.startswith('prd-'): env_val = "prod"
        elif app_name.startswith('stg-'): env_val = "stag"
        elif app_name.startswith('dev-'): env_val = "dev"

        shared_vpc_env_val = "dev" if env_val == "dev" else "prod" if shared_vpc_sn_val else "none"
        owner_val = str(proj.get('owner', 'unknown')).strip()

        tfvars_content = f"""# Auto-generated file. Do not edit manually.
organization_domain = "{domain}"
mgmt_project_id     = "{mgmt_project_id}"
app_name            = "{app_name}"
environment         = "{env_val}"
folder_id           = "{folder_id_val}"
shared_vpc_env      = "{shared_vpc_env_val}"
shared_vpc_subnet   = "{shared_vpc_sn_val}"
vpc_sc              = "{vpc_sc_val}"
monitoring          = {str(monitoring).lower()}
logging             = {str(logging).lower()}
budget_amount       = {budget_amount}
budget_alert_emails = {json.dumps(budget_emails)}
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
            headers = [cell.value for cell in ws[1] if cell.value is not None]
            rows = []
            for row in ws.iter_rows(min_row=2, values_only=True):
                if not any(row): continue
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
    print("\n" + "="*50 + "\n 🎉 Generation Complete!\n" + "="*50)
    print(" 1. [Verify] Review the generated files in terraform/4_projects/")
    print(" 2. [Lint]   Run 'make lint' to ensure code quality")
    print(" 3. [Check]  Run 'make check' to validate GCP environment")
    print(" 4. [Deploy] Run 'make deploy' to apply changes to GCP\n" + "="*50)

if __name__ == "__main__":
    generate_resources()
