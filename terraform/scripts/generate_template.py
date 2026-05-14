# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "openpyxl==3.1.2",
# ]
# ///
import os
from openpyxl import Workbook
from openpyxl.worksheet.datavalidation import DataValidation

def create_template():
    xlsx_path = os.path.join(
        os.path.dirname(__file__), '../../gcp-foundations.xlsx'
    )

    if os.path.exists(xlsx_path):
        print(f"⚠️  '{xlsx_path}' は既に存在します。上書きを避けるため処理を中断しました。")
        return

    wb = Workbook()
 
    # 定義データ
    sheets_config = {
        "resources": {
            "headers": [
                "resource_type", "parent_name", "resource_name", "owner",
                "budget_amount", "budget_alert_emails", "shared_vpc", "vpc_sc",
                "central_monitoring", "central_logging", "org_tags"
            ],
            "validations": [
                {"cols": "A", "formula": '"folder,project"'},
                {"cols": "I:J", "formula": '"TRUE,FALSE"'}
            ]
        },
        "shared_vpc_subnets": {
            "headers": [
                "host_project_env", "subnet_name", "region", "ip_cidr_range"
            ],
            "validations": [
                {"cols": "A", "formula": '"prod,dev"'},
                {"cols": "C", "formula": '"asia-northeast1,asia-northeast2,us-central1"'}
            ]
        },
        "vpc_sc_perimeters": {
            "headers": ["perimeter_name", "title", "restricted_services", "dry_run"],
            "validations": [
                {"cols": "D", "formula": '"TRUE,FALSE"'}
            ]
        },
        "vpc_sc_access_levels": {
            "headers": ["access_level_name", "ip_subnetworks", "members"]
        },
        "org_policies": {
            "headers": ["target_name", "policy_id", "enforce", "allow_list"],
            "validations": [
                {
                    "cols": "B",
                    "formula": (
                        '"iam.managed.disableServiceAccountKeyCreation,'
                        'iam.automaticIamGrantsForDefaultServiceAccounts,'
                        'iam.allowedPolicyMemberDomains,compute.vmExternalIpAccess,'
                        'compute.skipDefaultNetworkCreation,'
                        'compute.managed.requireOsLogin,gcp.resourceLocations,'
                        'sql.managed.restrictPublicIp"'
                    )
                },
                {"cols": "C", "formula": '"TRUE,FALSE"'}
            ]
        },
        "alert_definitions": {
            "headers": [
                "alert_name", "alert_display_name", "metric_filter",
                "alert_documentation"
            ]
        },
        "notifications": {
            "headers": ["alert_name", "user_email", "receive_alerts"],
            "validations": [
                {"cols": "C", "formula": '"TRUE,FALSE"'}
            ]
        },
        "log_sinks": {
            "headers": [
                "log_type", "filter", "destination_type", "destination_parent",
                "retention_days"
            ],
            "validations": [
                {"cols": "C", "formula": '"BigQuery,Cloud Storage"'}
            ]
        },
        "tag_definitions": {
            "headers": ["tag_key", "allowed_values", "description"]
        }
    }

    # デフォルトのSheetを削除
    std_sheet = wb.active
    wb.remove(std_sheet)

    for sname, config in sheets_config.items():
        ws = wb.create_sheet(sname)
        ws.append(config["headers"])

        # サジェスト（プルダウン）の設定
        if "validations" in config:
            for v in config["validations"]:
                dv = DataValidation(
                    type="list", 
                    formula1=v["formula"], 
                    allow_blank=True
                )
                # 自由入力を許可するための魔法の設定
                dv.showErrorMessage = False 

                ws.add_data_validation(dv)
                # 2行目から100行目まで適用
                if ":" in v["cols"]:
                    col_start, col_end = v["cols"].split(":")
                    dv.add(f"{col_start}2:{col_end}100")
                else:
                    dv.add(f"{v['cols']}2:{v['cols']}100")

    wb.save(xlsx_path)
    print(f"✅ プルダウン（サジェスト）付きのテンプレートを生成しました: {xlsx_path}")

if __name__ == "__main__":
    create_template()
