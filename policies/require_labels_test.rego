package terraform.validation_test

import rego.v1
import data.terraform.validation.deny

# 必須ラベルは撤廃済み（required_labels は空集合）。
# どのような labels の状態でもラベル欠如では deny されないことを確認する。

test_no_deny_when_labels_absent if {
    count(deny) == 0 with input as {
        "resource_changes": [
            {
                "type": "google_project",
                "address": "google_project.test",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "labels": {}
                    }
                }
            }
        ]
    }
}

test_no_deny_with_partial_labels if {
    count(deny) == 0 with input as {
        "resource_changes": [
            {
                "type": "google_project",
                "address": "google_project.test",
                "change": {
                    "actions": ["update"],
                    "after": {
                        "labels": {
                            "app": "my-app"
                        }
                    }
                }
            }
        ]
    }
}

test_no_deny_on_delete if {
    count(deny) == 0 with input as {
        "resource_changes": [
            {
                "type": "google_project",
                "address": "google_project.test",
                "change": {
                    "actions": ["delete"],
                    "after": {}
                }
            }
        ]
    }
}
