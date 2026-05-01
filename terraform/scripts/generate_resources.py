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

def to_snake_case(name):
    name = re.sub(r'[\.\s-]', '_', str(name))
    name = re.sub(r'(.)([A-Z][a-z]+)', r'\1_\2', name)
    name = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', name).lower()
    return name

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
            key = str(t_dict.get('tag_key') or '').strip()
            if key:
                allowed = [v.strip() for v in str(t_dict.get('allowed_values') or '').split(',') if v.strip()]
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
            res_name = str(row_dict.get('resource_name') or '').strip()
            res_type = str(row_dict.get('resource_type') or '').strip().lower()
            if res_type == 'folder': folders_map[res_name] = str(row_dict.get('parent_name') or '').strip()
            elif res_type == 'project': projects.append(row_dict)

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

    folders_tf_path = os.path.join(os.path.dirname(__file__), '../3_folders/auto_folders.tf')
    with open(folders_tf_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.

")
        for folder_name, parent_name in folders_map.items():
            fid = sanitize_id(folder_name)
            parent_str = str(parent_name).strip()
            parent_expr = "data.google_organization.org.name" if parent_str == 'organization_id' else f"google_folder.{sanitize_id(parent_str)}.name"
            f.write(f'resource "google_folder" "{fid}" {{
  display_name = "{folder_name}"
  parent = {parent_expr}
  deletion_protection = false
}}

')
            f.write(f'output "{fid}_folder_id" {{
  description = "The resource ID of the {folder_name} folder."
  value = google_folder.{fid}.id
}}

')

    tags_tf_path = os.path.join(os.path.dirname(__file__), '../2_organization/auto_tags.tf')
    with open(tags_tf_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.

")
        tag_value_map = {}
        for key, info in tag_definitions.items():
            kid = sanitize_id(key)
            f.write(f'resource "google_tags_tag_key" "{kid}" {{
  count = var.enable_tags ? 1 : 0
  parent = "organizations/${{data.google_organization.org.org_id}}"
  short_name = "{key}"
  description = "{info["description"]}"
}}

')
            for val in info['allowed_values']:
                vid = sanitize_id(f"{key}_{val}")
                f.write(f'resource "google_tags_tag_value" "{vid}" {{
  count = var.enable_tags ? 1 : 0
  parent = google_tags_tag_key.{kid}[0].id
  short_name = "{val}"
}}

')
                tag_value_map[f"{key}/{val}"] = f"try(google_tags_tag_value.{vid}[0].id, null)"
        f.write('output "tag_value_ids" {
  description = "Map of organization tag key/value pairs to their resource IDs."
  value = {
')
        for k, v in tag_value_map.items(): f.write(f'    "{k}" = {v}
')
        f.write('  }
}

')

    def export_sheet_to_csv(sheet_name, output_path):
        if sheet_name in wb.sheetnames:
            ws = wb[sheet_name]
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            header_row = [cell.value for cell in ws[1]]
            valid_col_indices = [i for i, h in enumerate(header_row) if h is not None and str(h).strip() != ""]
            if not valid_col_indices: return
            with open(output_path, 'w', newline='', encoding='utf-8') as csv_file:
                writer = csv.writer(csv_file)
                for row in ws.iter_rows(values_only=True):
                    if not any(cell is not None and str(cell).strip() != "" for cell in row): continue
                    filtered_row = [str(row[i]) if i < len(row) and row[i] is not None else "" for i in valid_col_indices]
                    writer.writerow(filtered_row)

    export_sheet_to_csv('log_sinks', os.path.join(os.path.dirname(__file__), '../1_core/services/logsink/sinks/gcp_log_sink_config.csv'))
    export_sheet_to_csv('alert_definitions', os.path.join(os.path.dirname(__file__), '../1_core/services/monitoring/2_alert_policies/logsink_log_alerts/alert_definitions.csv'))
    export_sheet_to_csv('notifications', os.path.join(os.path.dirname(__file__), '../1_core/services/monitoring/1_notification_channels/notifications.csv'))
    export_sheet_to_csv('notifications', os.path.join(os.path.dirname(__file__), '../1_core/services/monitoring/2_alert_policies/logsink_log_alerts/notifications.csv'))

    subnets_tf_path = os.path.join(os.path.dirname(__file__), '../1_core/base/vpc-host/auto_subnets.tf')
    if 'shared_vpc_subnets' in wb.sheetnames:
        with open(subnets_tf_path, 'w') as f:
            f.write("# Auto-generated file. Do not edit manually.

")
            ws = wb['shared_vpc_subnets']
            headers = [cell.value for cell in ws[1]]
            subnet_outputs = []
            used_cidrs = []
            for idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
                if not any(row): continue
                s = dict(zip(headers, row))
                s_name = str(s.get('subnet_name') or '').strip()
                env = str(s.get('host_project_env') or '').strip().lower()
                cidr = str(s.get('ip_cidr_range') or '').strip()
                region = str(s.get('region') or '').strip()
                if cidr:
                    err = validator.validate_cidr(cidr, used_cidrs)
                    if err: errors.append(f"[shared_vpc_subnets] Row {idx}: {err}")
                    else: used_cidrs.append(ipaddress.ip_network(cidr, strict=True))
                if s_name and env in ['prod', 'dev']:
                    sid = sanitize_id(s_name)
                    f.write(f'resource "google_compute_subnetwork" "{sid}" {{
  name = "{s_name}"
  ip_cidr_range = "{cidr}"
  region = "{region}"
  network = google_compute_network.vpc_{env}[0].id
  project = module.vpc_host_{env}[0].project_id
  private_ip_google_access = true
}}

')
                    subnet_outputs.append(f'    "{s_name}" = google_compute_subnetwork.{sid}.id')
            f.write('output "shared_vpc_subnet_ids" {
  description = "Map of shared VPC subnet names to their resource IDs."
  value = {
')
            f.write('
'.join(subnet_outputs) + '
  }
}

')

    vpc_sc_tf_path = os.path.join(os.path.dirname(__file__), '../2_organization/auto_vpc_sc.tf')
    with open(vpc_sc_tf_path, 'w') as f:
        f.write("# Auto-generated file. Do not edit manually.

")
        access_level_ids = {}
        if 'vpc_sc_access_levels' in wb.sheetnames:
            ws = wb['vpc_sc_access_levels']
            headers = [cell.value for cell in ws[1]]
            for row in ws.iter_rows(min_row=2, values_only=True):
                if not any(row): continue
                al = dict(zip(headers, row))
                if not al.get('access_level_name'): continue
                sid = sanitize_id(al['access_level_name'])
                f.write(f'resource "google_access_context_manager_access_level" "{sid}" {{
  count = var.enable_vpc_sc ? 1 : 0
  parent = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}"
  name = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}/accessLevels/{al["access_level_name"]}"
  title = "{al["access_level_name"]}"
  basic {{
    conditions {{
')
                if al.get('ip_subnetworks'):
                    ips = [ip.strip() for ip in str(al['ip_subnetworks']).split(',') if ip.strip()]
                    f.write(f'      ip_subnetworks = {json.dumps(ips)}
')
                if al.get('members'):
                    members = [m.strip() for m in str(al['members']).split(',') if m.strip()]
                    f.write(f'      members = {json.dumps(members)}
')
                f.write(f'    }}
  }}
}}

')
                access_level_ids[al["access_level_name"]] = f"var.enable_vpc_sc ? google_access_context_manager_access_level.{sid}[0].name : null"
        perimeter_ids = {}
        for p in perimeters:
            if not p.get('perimeter_name'): continue
            sid = sanitize_id(p['perimeter_name'])
            services = [s.strip() for s in str(p.get('restricted_services') or '').split(',') if s.strip()]
            f.write(f'resource "google_access_context_manager_service_perimeter" "{sid}" {{
  count = var.enable_vpc_sc ? 1 : 0
  parent = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}"
  name = "accessPolicies/${{google_access_context_manager_access_policy.access_policy[0].name}}/servicePerimeters/{p["perimeter_name"]}"
  title = "{p["perimeter_name"]}"
  status {{
    restricted_services = {json.dumps(services)}
  }}
  lifecycle {{ ignore_changes = [status[0].resources] }}
}}

')
            perimeter_ids[p['perimeter_name']] = f"var.enable_vpc_sc ? google_access_context_manager_service_perimeter.{sid}[0].name : null"
        f.write('output "service_perimeter_ids" {
  description = "Map of VPC-SC perimeter names to their resource IDs."
  value = {
')
        for k, v in perimeter_ids.items(): f.write(f'    "{k}" = {v}
')
        f.write('  }
}

')
        f.write('output "access_level_ids" {
  description = "Map of VPC-SC access level names to their resource IDs."
  value = {
')
        for k, v in access_level_ids.items(): f.write(f'    "{k}" = {v}
')
        f.write('  }
}

')

    if 'org_policies' in wb.sheetnames:
        org_policy_files = {}
        ws = wb['org_policies']
        headers = [cell.value for cell in ws[1]]
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row): continue
            p = dict(zip(headers, row))
            target_name = str(p.get('target_name') or '').strip()
            if not target_name: continue
            
            parent_type = "organizations" if target_name == 'organization_id' else "folders"
            parent_path_part = f"data.google_organization.org.org_id" if target_name == 'organization_id' else f"google_folder.{sanitize_id(target_name)}.name"
            parent_resource = f"{parent_type}/${{{parent_path_part}}}"

            tf_file_path = f"../2_organization/auto_org_policies.tf" if target_name == 'organization_id' else f"../3_folders/auto_org_policies.tf"
            if tf_file_path not in org_policy_files:
                org_policy_files[tf_file_path] = []

            policy_id = str(p.get('policy_id') or '').strip()
            res_name = to_snake_case(f"{target_name}_{policy_id}")
            
            tf_block = f'resource "google_org_policy_policy" "{res_name}" {{
'
            tf_block += f'  count  = var.enable_org_policies ? 1 : 0
'
            tf_block += f'  name   = "{parent_resource}/policies/{policy_id}"
'
            tf_block += f'  parent = "{parent_resource}"
'
            tf_block += f'  spec {{
'
            if is_true(p.get('enforce')):
                tf_block += f'    rules {{
      enforce = "true"
    }}
'
            elif str(p.get('enforce')).strip().lower() == 'false':
                 tf_block += f'    rules {{
      enforce = "false"
    }}
'
            else:
                values = [v.strip() for v in str(p.get('allow_list') or '').split(',') if v.strip()]
                tf_block += f'    rules {{
      values {{
        allowed_values = {json.dumps(values)}
      }}
    }}
'
            tf_block += f'  }}
}}
'
            org_policy_files[tf_file_path].append(tf_block)

        for path, blocks in org_policy_files.items():
            full_path = os.path.join(os.path.dirname(__file__), path)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, 'w') as f:
                f.write("# Auto-generated file. Do not edit manually.

")
                f.write("
".join(blocks))

    template_dir = os.path.join(os.path.dirname(__file__), '../4_projects/template')
    for proj in projects:
        app_name = str(proj.get('resource_name') or '').strip()
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
                    f.write(f'terraform {{
  backend "gcs" {{
    bucket = ""
    prefix = "projects/{app_name}"
  }}
}}
')

        parent_folder = str(proj.get('parent_name') or '').strip()
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
  env   = "{'prod' if app_name.startswith('prd-') else 'stag' if app_name.startswith('stg-') else 'dev'}"
  owner = "{str(proj.get('owner') or 'unknown').strip()}"
  app   = "{app_name}"
}}
"""
        with open(os.path.join(project_dir, 'terraform.tfvars'), 'w') as f: f.write(tfvars_content)

    print(f"✅ Generated all resources successfully")
