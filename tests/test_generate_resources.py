import pytest
import sys
import os
import ipaddress

# Add the script directory to the path so we can import ResourceValidator
sys.path.append(os.path.join(os.path.dirname(__file__), '../terraform/scripts'))
from generate_resources import (
    ResourceValidator,
    resolve_environment,
    infer_env_from_name,
    resolve_shared_vpc_env,
)

@pytest.fixture
def validator():
    return ResourceValidator()

# --- Naming Convention Tests ---

def test_validate_project_name_valid(validator):
    assert validator.validate_gcp_resource_name("prd-app-01", "project") is None
    assert validator.validate_gcp_resource_name("my-project-123", "project") is None

def test_validate_project_name_invalid(validator):
    assert validator.validate_gcp_resource_name("Prd-App", "project") is not None # Uppercase
    assert validator.validate_gcp_resource_name("123project", "project") is not None # Starts with number
    assert validator.validate_gcp_resource_name("proj", "project") is not None # Too short
    assert validator.validate_gcp_resource_name("a"*31, "project") is not None # Too long
    assert validator.validate_gcp_resource_name("project_", "project") is not None # Ends with underscore/invalid

def test_validate_project_name_with_prefix(validator):
    assert validator.validate_gcp_resource_name("app-01", "project", prefix="my-company") is None
    assert validator.validate_gcp_resource_name("a"*20, "project", prefix="my-company") is not None # prefix(10) + hypen(1) + name(20) = 31 > 30

def test_validate_folder_name_valid(validator):
    assert validator.validate_gcp_resource_name("Production", "folder") is None
    assert validator.validate_gcp_resource_name("Shared VPC", "folder") is None

def test_validate_folder_name_invalid(validator):
    assert validator.validate_gcp_resource_name("a"*31, "folder") is not None # Too long
    assert validator.validate_gcp_resource_name("Folder!", "folder") is not None # Special char

# --- CIDR Validation Tests ---

def test_validate_cidr_valid(validator):
    assert validator.validate_cidr("10.0.0.0/24", []) is None
    assert validator.validate_cidr("192.168.1.0/24", [ipaddress.ip_network("10.0.0.0/8")]) is None

def test_validate_cidr_invalid_format(validator):
    assert validator.validate_cidr("10.0.0.300/24", []) is not None
    assert validator.validate_cidr("not-a-cidr", []) is not None

def test_validate_cidr_overlap(validator):
    import ipaddress
    used = [ipaddress.ip_network("10.0.0.0/16")]
    assert validator.validate_cidr("10.0.1.0/24", used) is not None

def test_validate_cidr_strict_check(validator):
    # 10.0.1.5/24 is invalid because host bits are set
    assert validator.validate_cidr("10.0.1.5/24", []) is not None

# --- Hierarchy Validation Tests ---

def test_validate_hierarchy_valid(validator):
    resources = [
        {"resource_type": "folder", "resource_name": "shared", "parent_name": "organization_id", "central_monitoring": False, "central_logging": False},
        {"resource_type": "project", "resource_name": "prd-app-01", "parent_name": "shared", "central_monitoring": True, "central_logging": True}
    ]
    assert validator.validate_hierarchy(resources) == []

def test_validate_hierarchy_circular(validator):
    resources = [
        {"resource_type": "folder", "resource_name": "folder-a", "parent_name": "folder-a"}
    ]
    errors = validator.validate_hierarchy(resources)
    assert any("circular reference" in e for e in errors)

def test_validate_hierarchy_missing_parent(validator):
    resources = [
        {"resource_type": "project", "resource_name": "prd-app-01", "parent_name": "non-existent-folder"}
    ]
    errors = validator.validate_hierarchy(resources)
    assert any("not defined" in e for e in errors)

def test_validate_hierarchy_duplicate_names(validator):
    resources = [
        {"resource_type": "folder", "resource_name": "app-01", "parent_name": "organization_id"},
        {"resource_type": "project", "resource_name": "app-01", "parent_name": "organization_id"}
    ]
    errors = validator.validate_hierarchy(resources)
    assert any("Duplicate resource name" in e for e in errors)

# --- Project Reference and Org Policy Validation Tests ---

def test_validate_project_refs(validator):
    resources = [
        {"resource_type": "project", "resource_name": "app1", "shared_vpc": "valid-subnet", "vpc_sc": "valid-perimeter"},
        {"resource_type": "project", "resource_name": "app2", "shared_vpc": "invalid-subnet", "vpc_sc": "invalid-perimeter"}
    ]
    subnets = [{"subnet_name": "valid-subnet"}]
    perimeters = [{"perimeter_name": "valid-perimeter"}]
    errors = validator.validate_project_refs(resources, subnets, perimeters)
    assert len(errors) == 2
    assert any("invalid-subnet" in e for e in errors)
    assert any("invalid-perimeter" in e for e in errors)

def test_validate_org_policies(validator):
    folders = {"shared"}
    projects = {"prd-app-01"}
    policies = [
        {"target_name": "organization_id"},
        {"target_name": "shared"},
        {"target_name": "prd-app-01"},
        {"target_name": "invalid-target"}
    ]
    errors = validator.validate_org_policies(policies, folders, projects)
    assert len(errors) == 1
    assert "invalid-target" in errors[0]

def test_validate_org_policies_apply_mode_valid(validator):
    folders = {"shared"}
    projects = {"prd-app-01"}
    # live/dryrun/both は有効。空欄・未指定は live 扱いで有効（後方互換）。
    for mode in ["live", "dryrun", "both", "BOTH", "", None]:
        policies = [{"target_name": "organization_id", "apply_mode": mode}]
        errors = validator.validate_org_policies(policies, folders, projects)
        assert errors == [], f"apply_mode={mode!r} should be valid but got {errors}"

def test_validate_org_policies_apply_mode_invalid(validator):
    folders = {"shared"}
    projects = {"prd-app-01"}
    policies = [{"target_name": "organization_id", "apply_mode": "audit"}]
    errors = validator.validate_org_policies(policies, folders, projects)
    assert len(errors) == 1
    assert "apply_mode" in errors[0]

# --- Tag Validation Tests ---

def test_validate_tags_valid(validator):
    definitions = {'environment': {'allowed_values': ['production', 'development']}}
    assert validator.validate_tags("environment/production", definitions) is None
    assert validator.validate_tags("environment/production, environment/development", definitions) is None

def test_validate_tags_invalid_format(validator):
    definitions = {'environment': {'allowed_values': ['production']}}
    assert validator.validate_tags("environment:production", definitions) is not None # Missing slash

def test_validate_tags_undefined_key(validator):
    definitions = {'environment': {'allowed_values': ['production']}}
    assert validator.validate_tags("cost_center/123", definitions) is not None

def test_validate_tags_undefined_value(validator):
    definitions = {'environment': {'allowed_values': ['production']}}
    assert validator.validate_tags("environment/sandbox", definitions) is not None

def test_validate_alerts_duplicate(validator):
    alert_defs = [{"alert_name": "alert1"}, {"alert_name": "alert1"}]
    errors = validator.validate_alerts([], alert_defs)
    assert any("Duplicate alert_name" in e for e in errors)

def test_validate_alerts_documentation_required(validator):
    alert_defs = [{"alert_name": "alert1", "alert_documentation": ""}]
    errors = validator.validate_alerts([], alert_defs)
    assert any("alert_documentation" in e for e in errors)

def test_validate_alerts_documentation_none(validator):
    alert_defs = [{"alert_name": "alert1"}]
    errors = validator.validate_alerts([], alert_defs)
    assert any("alert_documentation" in e for e in errors)

def test_validate_log_sinks_duplicate(validator):
    log_sinks = [{"log_type": "エラーログ"}, {"log_type": "エラーログ"}]
    errors = validator.validate_log_sinks(log_sinks)
    assert any("Duplicate log_type" in e for e in errors)

def test_validate_log_sinks_bigquery_hyphen(validator):
    log_sinks = [{"log_type": "エラーログ", "destination_type": "BigQuery", "destination_parent": "error-logs"}]
    errors = validator.validate_log_sinks(log_sinks)
    assert any("ハイフン" in e for e in errors)

def test_validate_log_sinks_bigquery_no_hyphen(validator):
    log_sinks = [{"log_type": "エラーログ", "destination_type": "BigQuery", "destination_parent": "error_logs"}]
    errors = validator.validate_log_sinks(log_sinks)
    assert not any("ハイフン" in e for e in errors)

# --- Environment Resolution Tests ---

def test_infer_env_from_name():
    assert infer_env_from_name("prd-app") == "prod"
    assert infer_env_from_name("stg-app") == "stag"
    assert infer_env_from_name("dev-app") == "dev"
    assert infer_env_from_name("app-foo") is None
    assert infer_env_from_name("") is None

def test_resolve_environment_explicit_wins():
    # 明示値（許可値）はそのまま採用
    assert resolve_environment("app-foo", "prod") == ("prod", None)

def test_resolve_environment_explicit_normalized():
    # 大文字/空白は正規化される
    env, err = resolve_environment("app-foo", "  PROD ")
    assert env == "prod" and err is None

def test_resolve_environment_invalid_explicit():
    env, err = resolve_environment("app-foo", "production")
    assert env is None and err is not None and "許可外" in err

def test_resolve_environment_conflict():
    # 接頭辞 prd-（prod推定）と明示 dev が矛盾 → エラー
    env, err = resolve_environment("prd-app", "dev")
    assert env is None and err is not None and "矛盾" in err

def test_resolve_environment_explicit_matches_prefix():
    assert resolve_environment("prd-app", "prod") == ("prod", None)

def test_resolve_environment_blank_is_error():
    # 空欄は必須エラー（接頭辞があっても補完しない＝暗黙挙動を排除）
    env, err = resolve_environment("stg-app", "")
    assert env is None and err is not None and "未指定" in err
    env2, err2 = resolve_environment("app-foo", None)
    assert env2 is None and err2 is not None and "未指定" in err2

def test_resolve_shared_vpc_env():
    # shared_vpc 未指定 → none
    assert resolve_shared_vpc_env("prod", "") == "none"
    assert resolve_shared_vpc_env("dev", None) == "none"
    # 指定あり → dev は dev ホスト、prod/stag は prod ホスト（ホストは2種のみ）
    assert resolve_shared_vpc_env("dev", "subnet-a") == "dev"
    assert resolve_shared_vpc_env("prod", "subnet-a") == "prod"
    assert resolve_shared_vpc_env("stag", "subnet-a") == "prod"
