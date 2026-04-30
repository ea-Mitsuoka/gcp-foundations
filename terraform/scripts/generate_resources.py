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
import csv
from openpyxl import Workbook
from openpyxl.worksheet.datavalidation import DataValidation

# --- Validation Logic ---

class ResourceValidator:
    @staticmethod
    def validate_gcp_resource_name(name, resource_type):
        if not name: return "Resource name is empty."
        name = str(name).strip()
        if resource_type == 'project':
            if not re.match(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$', name):
                return f"Project name '{name}' is invalid (6-30 chars, lowercase, numbers, hyphens, starts with letter, ends with alphanumeric)."
        elif resource_type == 'folder':
            if not re.match(r'^[a-zA-Z0-9- ]{1,30}$', name):
                return f"Folder name '{name}' is invalid (1-30 chars, alphanumeric, hyphens, spaces only)."
        return None

    @staticmethod
    def validate_cidr(cidr, used_cidrs):
        if not cidr: return None
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
        errors = []
        folders = {str(r['resource_name']).strip() for r in resources if str(r['resource_type']).strip().lower() == 'folder'}
        for r in resources:
            name = str(r['resource_name']).strip()
            parent = str(r['parent_name']).strip()
            res_type = str(r['resource_type']).strip().lower()
            if name == parent:
                errors.append(f"Resource '{name}' cannot have itself as a parent.")
            if parent != 'organization_id' and parent not in folders:
                errors.append(f"{res_type.capitalize()} '{name}' refers to parent '{parent}' which is not defined.")
        return errors

    @staticmethod
    def validate_tags(org_tags_str, tag_definitions):
        if not org_tags_str: return None
        tags = [t.strip() for t in org_tags_str.split(',') if t.strip()]
        for tag in tags:
            if '/' not in tag: return f"Invalid tag format '{tag}'. Must be 'key/value'."
            key, val = tag.split('/', 1)
            if key not in tag_definitions: return f"Tag key '{key}' is not defined."
            if val not in tag_definitions[key]['allowed_values']:
                return f"Tag value '{val}' not allowed for '{key}'."
        return None

# --- Helper functions ---

def sanitize_id(name):
    if not name: return "unknown"
    return str(name).replace("-", "_").replace(" ", "_").replace(".", "_")

def add_validation(ws, col_letter, formula, title, prompt):
    dv = DataValidation(type="list", formula1=formula, allow_blank=True)
    dv.errorTitle = "Input Error"
    dv.error = f"Please select from the options in {title}."
    dv.promptTitle = title
    dv.prompt = prompt
    ws.add_data_validation(dv)
    dv.add(f"{col_letter}2:{col_letter}100")

def generate_resources():
    domain_env_path = os.path.join(os.path.dirname(__file__), '../../domain.env')
    domain = ""
    if os.path.exists(domain_env_path):
        with open(domain_env_path, 'r') as f:
            for line in f:
                if line.startswith('domain='):
                    domain = line.split('=')[1].strip().strip('"')
                    break

    mgmt_project_id = ""
    bootstrap_vars_path = os.path.join(os.path.dirname(__file__), '../0_bootstrap/terraform.tfvars')
    if os.path.exists(bootstrap_vars_path):
        with open(bootstrap_vars_path, 'r') as f:
            for line in f:
                if 'project_id' in line:
                    mgmt_project_id = line.split('=')[1].strip().strip('"')

    xlsx_path = os.path.join(os.path.dirname(__file__), '../../gcp-foundations.xlsx')
    if not os.path.exists(xlsx_path):
        print(f"{xlsx_path} not found. Creating a template...")
        wb = Workbook()
        ws = wb.active
        ws.title = "resources"
        headers = ["resource_type", "parent_name", "resource_name", "owner", "org_tags", "budget_amount", "budget_alert_emails", "shared_vpc", "vpc_sc", "central_monitoring", "central_logging"]
        ws.append(headers)
        wb.save(xlsx_path)

    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    required_sheets = {
        "resources": ["resource_type", "parent_name", "resource_name", "owner", "org_tags", "budget_amount", "budget_alert_emails", "shared_vpc", "vpc_sc", "central_monitoring", "central_logging"],
        "tag_definitions": ["tag_key", "allowed_values", "description"],
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
            ws = wb.create_sheet(sname)
            ws.append(headers)
            updated = True
    if updated: wb.save(xlsx_path)

    errors = []
    validator = ResourceValidator()
    
    tag_definitions = {}
    if 'tag_definitions' in wb.sheetnames:
        ws = wb['tag_definitions']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            t_dict = dict(zip(headers, row))
            key = str(t_dict.get('tag_key', '')).strip()
            if key:
                allowed = [v.strip() for v in str(t_dict.get('allowed_values', '')).split(',') if v.strip()]
                tag_definitions[key] = {'allowed_values': allowed, 'description': t_dict.get('description')}

    perimeters = []
    valid_perimeters = set()
    if 'vpc_sc_perimeters' in wb.sheetnames:
        ws = wb['vpc_sc_perimeters']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            p_dict = dict(zip(headers, row))
            perimeters.append(p_dict)
            if p_dict.get('perimeter_name'): valid_perimeters.add(str(p_dict['perimeter_name']).strip())

    subnets = []
    valid_subnets = set()
    used_cidrs = []
    if 'shared_vpc_subnets' in wb.sheetnames:
        ws = wb['shared_vpc_subnets']
        headers = [cell.value for cell in ws[1]]
        for idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
            if not any(row): continue
            s_dict = dict(zip(headers, row))
            subnets.append(s_dict)
            s_name = str(s_dict.get('subnet_name', '')).strip()
            if s_name: valid_subnets.add(s_name)
            cidr = str(s_dict.get('ip_cidr_range', '')).strip()
            if cidr:
                cidr_err = validator.validate_cidr(cidr, used_cidrs)
                if cidr_err: errors.append(f"[shared_vpc_subnets] Row {idx}: {cidr_err}")
                else:
                    try: used_cidrs.append(ipaddress.ip_network(cidr, strict=True))
                    except: pass

    all_resource_names = set() 
    folders_map = {}
    projects = []
    resources_data = []
    if 'resources' in wb.sheetnames:
        ws = wb['resources']
        headers = [cell.value for cell in ws[1]]
        for idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
            if not any(row): continue
            row_dict = dict(zip(headers, row))
            resources_data.append(row_dict)
            res_name = str(row_dict.get('resource_name', '')).strip()
            res_type = str(row_dict.get('resource_type', '')).strip().lower()
            org_tags = str(row_dict.get('org_tags', '')).strip()
            name_err = validator.validate_gcp_resource_name(res_name, res_type)
            if name_err: errors.append(f"[resources] Row {idx}: {name_err}")
            tag_err = validator.validate_tags(org_tags, tag_definitions)
            if tag_err: errors.append(f"[resources] Row {idx}: {tag_err}")
            if res_name in all_resource_names: errors.append(f"[resources] Row {idx}: Duplicate name '{res_name}'.")
            all_resource_names.add(res_name)
            if res_type == 'folder': folders_map[res_name] = str(row_dict.get('parent_name', '')).strip()
            elif res_type == 'project': projects.append(row_dict)

    if errors:
        print("\n❌ Configuration errors detected:")
        for err in errors: print(f"  - {err}")
        sys.exit(1)

    def is_true(val):
        if val is None: return False
        if isinstance(val, bool): return val
        return str(val).strip().lower() == 'true'

    # 4. Folders
    folders_tf_path = os.path.join(os.path.dirname(__file__), '../3_folders/auto_folders.tf')
    with open(folders_tf_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.\n\n")
        for folder_name, parent_name in folders_map.items():
            fid = sanitize_id(folder_name)
            parent_str = str(parent_name).strip()
            parent_expr = "data.google_organization.org.name" if parent_str == 'organization_id' else f"google_folder.{sanitize_id(parent_str)}.name"
            folder_data = next((r for r in resources_data if r['resource_name'] == folder_name), {})
            folder_tags = [t.strip() for t in str(folder_data.get('org_tags', '')).split(',') if t.strip()]
            f.write(f'resource "google_folder" "{fid}" {{\n  display_name = "{folder_name}"\n  parent = {parent_expr}\n  deletion_protection = false\n}}\n\n')
            for tag in folder_tags:
                tid = sanitize_id(f"{folder_name}_{tag.replace('/', '_')}")
                f.write(f'resource "google_tags_tag_binding" "{tid}" {{\n  count = var.enable_tags && length(data.terraform_remote_state.organization) > 0 ? 1 : 0\n  parent = "//cloudresourcemanager.googleapis.com/${{google_folder.{fid}.name}}"\n  tag_value = data.terraform_remote_state.organization[0].outputs.tag_value_ids["{tag}"]\n}}\n\n')
            f.write(f'output "{fid}_folder_id" {{\n  value = google_folder.{fid}.id\n}}\n\n')

    # 5. Tag Definitions
    tags_tf_path = os.path.join(os.path.dirname(__file__), '../2_organization/auto_tags.tf')
    with open(tags_tf_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.\n\n")
        tag_value_map = {}
        for key, info in tag_definitions.items():
            kid = sanitize_id(key)
            f.write(f'resource "google_tags_tag_key" "{kid}" {{\n  count = var.enable_tags ? 1 : 0\n  parent = "organizations/${{data.google_organization.org.org_id}}"\n  short_name = "{key}"\n  description = "{info["description"]}"\n}}\n\n')
            for val in info['allowed_values']:
                vid = sanitize_id(f"{key}_{val}")
                f.write(f'resource "google_tags_tag_value" "{vid}" {{\n  count = var.enable_tags ? 1 : 0\n  parent = google_tags_tag_key.{kid}[0].id\n  short_name = "{val}"\n}}\n\n')
                tag_value_map[f"{key}/{val}"] = f"try(google_tags_tag_value.{vid}[0].id, null)"
        f.write(f'output "tag_value_ids" {{\n  value = {{\n')
        for k, v in tag_value_map.items(): f.write(f'    "{k}" = {v}\n')
        f.write(f'  }}\n}}\n\n')

    # 6. VPC-SC
    vpc_sc_tf_path = os.path.join(os.path.dirname(__file__), '../2_organization/auto_vpc_sc.tf')
    with open(vpc_sc_tf_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.\n\n")
        access_level_ids = {}
        if 'vpc_sc_access_levels' in wb.sheetnames:
            ws = wb['vpc_sc_access_levels']
            headers = [cell.value for cell in ws[1]]
            for row in ws.iter_rows(min_row=2, values_only=True):
                if not any(row): continue
                al = dict(zip(headers, row))
                if not al.get('access_level_name'): continue
                sid = sanitize_id(al['access_level_name'])
                f.write(f'resource "google_access_context_manager_access_level" "{sid}" {{\n  count = var.enable_vpc_sc ? 1 : 0\n  parent = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}"\n  name = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}/accessLevels/{al["access_level_name"]}"\n  title = "{al["access_level_name"]}"\n  basic {{\n    conditions {{\n')
                if al.get('ip_subnetworks'):
                    ips = [ip.strip() for ip in str(al['ip_subnetworks']).split(',') if ip.strip()]
                    f.write(f'      ip_subnetworks = {json.dumps(ips)}\n')
                if al.get('members'):
                    members = [m.strip() for m in str(al['members']).split(',') if m.strip()]
                    f.write(f'      members = {json.dumps(members)}\n')
                f.write(f'    }}\n  }}\n}}\n\n')
                access_level_ids[al["access_level_name"]] = f"var.enable_vpc_sc ? google_access_context_manager_access_level.{sid}[0].name : null"
        perimeter_ids = {}
        for p in perimeters:
            if not p.get('perimeter_name'): continue
            sid = sanitize_id(p['perimeter_name'])
            services = [s.strip() for s in str(p.get('restricted_services', '')).split(',') if s.strip()]
            f.write(f'resource "google_access_context_manager_service_perimeter" "{sid}" {{\n  count = var.enable_vpc_sc ? 1 : 0\n  parent = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}"\n  name = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}/servicePerimeters/{p["perimeter_name"]}"\n  title = "{p["perimeter_name"]}"\n  status {{\n    restricted_services = {json.dumps(services)}\n  }}\n  lifecycle {{ ignore_changes = [status[0].resources] }}\n}}\n\n')
            perimeter_ids[p['perimeter_name']] = f"var.enable_vpc_sc ? google_access_context_manager_service_perimeter.{sid}[0].name : null"
        f.write(f'output "service_perimeter_ids" {{ value = {json.dumps(perimeter_ids).replace("\"", "")} }}\n')
        f.write(f'output "access_level_ids" {{ value = {json.dumps(access_level_ids).replace("\"", "")} }}\n\n')

    # 7. CSV Exports
    def export_sheet_to_csv(sheet_name, output_path):
        if sheet_name in wb.sheetnames:
            ws = wb[sheet_name]
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            with open(output_path, 'w', newline='', encoding='utf-8') as csv_file:
                writer = csv.writer(csv_file)
                for row in ws.iter_rows(values_only=True):
                    if any(cell is not None for cell in row):
                        writer.writerow(["" if cell is None else str(cell) for cell in row])
    export_sheet_to_csv('log_sinks', os.path.join(os.path.dirname(__file__), '../1_core/services/logsink/sinks/gcp_log_sink_config.csv'))
    export_sheet_to_csv('alert_definitions', os.path.join(os.path.dirname(__file__), '../1_core/services/monitoring/2_alert_policies/logsink_log_alerts/alert_definitions.csv'))
    export_sheet_to_csv('notifications', os.path.join(os.path.dirname(__file__), '../1_core/services/monitoring/1_notification_channels/notifications.csv'))
    export_sheet_to_csv('notifications', os.path.join(os.path.dirname(__file__), '../1_core/services/monitoring/2_alert_policies/logsink_log_alerts/notifications.csv'))

    # 8. Projects & Template Copying
    example_dir = os.path.join(os.path.dirname(__file__), '../4_projects/example_project')
    for proj in projects:
        app_name = str(proj.get('resource_name', '')).strip()
        if not app_name: continue
        project_dir = os.path.join(os.path.dirname(__file__), f"../4_projects/{app_name}")
        os.makedirs(project_dir, exist_ok=True)
        
        # --- Template Copying ---
        if os.path.exists(example_dir) and app_name != 'example_project':
            for filename in ['main.tf', 'variables.tf', 'provider.tf', 'versions.tf']:
                src = os.path.join(example_dir, filename)
                dst = os.path.join(project_dir, filename)
                if os.path.exists(src) and not os.path.exists(dst):
                    shutil.copy2(src, dst)
            backend_dst = os.path.join(project_dir, 'backend.tf')
            if not os.path.exists(backend_dst):
                with open(backend_dst, 'w') as f:
                    f.write(f'terraform {{\n  backend "gcs" {{\n    bucket = ""\n    prefix = "projects/{app_name}"\n  }}\n}}\n')

        parent_folder = str(proj.get('parent_name', '')).strip()
        folder_id_val = "" if parent_folder == 'organization_id' else parent_folder
        tfvars_content = f"""# Auto-generated file. Do not edit manually.
organization_domain = "{domain}"
mgmt_project_id     = "{mgmt_project_id}"
app_name            = "{app_name}"
environment         = "{'prod' if app_name.startswith('prd-') else 'stag' if app_name.startswith('stg-') else 'dev'}"
folder_id           = "{folder_id_val}"
shared_vpc_env      = "{'dev' if app_name.startswith('dev-') else 'prod' if proj.get('shared_vpc') else 'none'}"
shared_vpc_subnet   = "{str(proj.get('shared_vpc', '')).strip()}"
vpc_sc              = "{str(proj.get('vpc_sc', '')).strip()}"
central_monitoring  = {str(is_true(proj.get('central_monitoring'))).lower()}
central_logging     = {str(is_true(proj.get('central_logging'))).lower()}
budget_amount       = {proj.get('budget_amount', 0) or 0}
budget_alert_emails = {json.dumps([e.strip() for e in str(proj.get('budget_alert_emails', '')).split(',') if e.strip()])}
org_tags            = {json.dumps([t.strip() for t in str(proj.get('org_tags', '')).split(',') if t.strip()])}
deletion_protection = true
labels = {{
  env = "{'prod' if app_name.startswith('prd-') else 'stag' if app_name.startswith('stg-') else 'dev'}"
  owner = "{str(proj.get('owner', 'unknown')).strip()}"
  app = "{app_name}"
}}
"""
        with open(os.path.join(project_dir, 'terraform.tfvars'), 'w') as f: f.write(tfvars_content)
    print(f"✅ Generated all resources successfully")

if __name__ == "__main__":
    generate_resources()
