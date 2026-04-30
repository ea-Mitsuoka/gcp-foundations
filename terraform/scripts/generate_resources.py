# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "openpyxl==3.1.2",
# ]
# ///
import os
import shutil
import openpyxl
import json
import sys
import re
import ipaddress
import csv
from openpyxl import Workbook
from openpyxl.worksheet.datavalidation import DataValidation

class ResourceValidator:
    @staticmethod
    def validate_gcp_resource_name(name, resource_type):
        if not name: return "Resource name is empty."
        name = str(name).strip()
        if resource_type == 'project':
            if not re.match(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$', name):
                return f"Project name '{name}' is invalid."
        elif resource_type == 'folder':
            if not re.match(r'^[a-zA-Z0-9- ]{1,30}$', name):
                return f"Folder name '{name}' is invalid."
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
            return f"Invalid CIDR format: '{cidr}' ({e})."

    @staticmethod
    def validate_hierarchy(resources):
        errors = []
        folders = {str(r['resource_name']).strip() for r in resources if str(r['resource_type']).strip().lower() == 'folder'}
        for r in resources:
            name = str(r['resource_name']).strip()
            parent = str(r['parent_name']).strip()
            res_type = str(r['resource_type']).strip().lower()
            if name == parent:
                errors.append(f"Resource '{name}' circular reference.")
            if parent != 'organization_id' and parent not in folders:
                errors.append(f"{res_type.capitalize()} '{name}' refers to parent '{parent}' which is not defined.")
        return errors

    @staticmethod
    def validate_tags(org_tags_str, tag_definitions):
        if not org_tags_str: return None
        tags = [t.strip() for t in org_tags_str.split(',') if t.strip()]
        for tag in tags:
            if '/' not in tag: return f"Invalid tag format '{tag}'."
            key, val = tag.split('/', 1)
            if key not in tag_definitions: return f"Tag key '{key}' undefined."
            if val not in tag_definitions[key]['allowed_values']: return f"Tag value '{val}' not allowed for '{key}'."
        return None

def sanitize_id(name):
    if not name: return "unknown"
    return str(name).replace("-", "_").replace(" ", "_").replace(".", "_")

def add_validation(ws, col_letter, formula, title, prompt):
    dv = DataValidation(type="list", formula1=formula, allow_blank=True)
    dv.errorTitle = "Input Error"
    dv.error = f"Please select from {title}."
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
    if 'vpc_sc_perimeters' in wb.sheetnames:
        ws = wb['vpc_sc_perimeters']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            perimeters.append(dict(zip(headers, row)))

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
            if res_type == 'folder': folders_map[res_name] = str(row_dict.get('parent_name', '')).strip()
            elif res_type == 'project': projects.append(row_dict)


    # --- 復活したバリデーション処理 ---
    if resources_data:
        hierarchy_errors = validator.validate_hierarchy(resources_data)
        if hierarchy_errors: errors.extend(hierarchy_errors)
        for idx, r in enumerate(resources_data, start=2):
            name_err = validator.validate_gcp_resource_name(r.get('resource_name'), r.get('resource_type'))
            if name_err: errors.append(f"[resources] Row {idx}: {name_err}")
            tag_err = validator.validate_tags(str(r.get('org_tags') or ''), tag_definitions)
            if tag_err: errors.append(f"[resources] Row {idx}: {tag_err}")
            
    if errors:
        print("\n❌ Configuration errors detected:")
        for err in errors: print(f"  - {err}")
        sys.exit(1)

    def is_true(val):
        if val is None: return False
        if isinstance(val, bool): return val
        return str(val).strip().lower() == 'true'

    # CSV Exports
    def export_sheet_to_csv(sheet_name, output_path):
        if sheet_name in wb.sheetnames:
            ws = wb[sheet_name]
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            header_row = [cell.value for cell in ws[1]]
            valid_col_indices = [
                i for i, h in enumerate(header_row) 
                if h is not None and str(h).strip() != ""
            ]
            
            if not valid_col_indices:
                return

            with open(output_path, 'w', newline='', encoding='utf-8') as csv_file:
                writer = csv.writer(csv_file)
                for row in ws.iter_rows(values_only=True):
                    if not any(cell is not None and str(cell).strip() != "" for cell in row):
                        continue
                    
                    filtered_row = []
                    for i in valid_col_indices:
                        if i < len(row) and row[i] is not None:
                            filtered_row.append(str(row[i]))
                        else:
                            filtered_row.append("")
                    
                    writer.writerow(filtered_row)

    export_sheet_to_csv('log_sinks', os.path.join(os.path.dirname(__file__), '../1_core/services/logsink/sinks/gcp_log_sink_config.csv'))
    export_sheet_to_csv('alert_definitions', os.path.join(os.path.dirname(__file__), '../1_core/services/monitoring/2_alert_policies/logsink_log_alerts/alert_definitions.csv'))
    export_sheet_to_csv('notifications', os.path.join(os.path.dirname(__file__), '../1_core/services/monitoring/1_notification_channels/notifications.csv'))
    export_sheet_to_csv('notifications', os.path.join(os.path.dirname(__file__), '../1_core/services/monitoring/2_alert_policies/logsink_log_alerts/notifications.csv'))

    # VPC-SC Outputs Generation
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
        
        f.write('output "service_perimeter_ids" {\n  value = {\n')
        for k, v in perimeter_ids.items(): f.write(f'    "{k}" = {v}\n')
        f.write('  }\n}\n')
        
        f.write('output "access_level_ids" {\n  value = {\n')
        for k, v in access_level_ids.items(): f.write(f'    "{k}" = {v}\n')
        f.write('  }\n}\n\n')

    # Projects & Template Copying
    template_dir = os.path.join(os.path.dirname(__file__), '../4_projects/template')
    for proj in projects:
        app_name = str(proj.get('resource_name', '')).strip()
        if not app_name: continue
        project_dir = os.path.join(os.path.dirname(__file__), f"../4_projects/{app_name}")
        os.makedirs(project_dir, exist_ok=True)
        
        if os.path.exists(template_dir) and app_name != 'template':
            for filename in ['main.tf', 'variables.tf', 'provider.tf', 'versions.tf']:
                src = os.path.join(template_dir, filename)
                dst = os.path.join(project_dir, filename)
                if os.path.exists(src) and not os.path.exists(dst):
                    shutil.copy2(src, dst)
            backend_dst = os.path.join(project_dir, 'backend.tf')
            if not os.path.exists(backend_dst):
                with open(backend_dst, 'w') as f:
                    # --- 修正箇所: bucket = "" を復活させ、CIの -backend=false の validate を通過させる ---
                    f.write(f'terraform {{\n  backend "gcs" {{\n    bucket = ""\n    prefix = "projects/{app_name}"\n  }}\n}}\n')

        parent_folder = str(proj.get('parent_name', '')).strip()
        folder_id_val = "" if parent_folder == 'organization_id' else parent_folder
        tfvars_content = f"""# Auto-generated file. Do not edit manually.
organization_domain = "{domain}"
mgmt_project_id     = "{mgmt_project_id}"
app_name            = "{app_name}"
environment         = "{'prod' if app_name.startswith('prd-') else 'stag' if app_name.startswith('stg-') else 'dev'}"
folder_id           = "{folder_id_val}"
shared_vpc_env      = "{'dev' if app_name.startswith('dev-') and proj.get('shared_vpc') else 'prod' if proj.get('shared_vpc') else 'none'}"
shared_vpc_subnet   = "{str(proj.get('shared_vpc') or '').strip()}"
vpc_sc              = "{str(proj.get('vpc_sc') or '').strip()}"
central_monitoring  = {str(is_true(proj.get('central_monitoring'))).lower()}
central_logging     = {str(is_true(proj.get('central_logging'))).lower()}
budget_amount       = {proj.get('budget_amount', 0) or 0}
budget_alert_emails = {json.dumps([e.strip() for e in str(proj.get('budget_alert_emails') or '').split(',') if e.strip()])}
org_tags            = {json.dumps([t.strip() for t in str(proj.get('org_tags') or '').split(',') if t.strip()])}
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
