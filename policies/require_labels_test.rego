package terraform.validation_test

import rego.v1
import data.terraform.validation.deny

test_deny_missing_all_labels if {
    count(deny) == 1 with input as {
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

test_deny_missing_some_labels if {
    count(deny) == 1 with input as {
        "resource_changes": [
            {
                "type": "google_project",
                "address": "google_project.test",
                "change": {
                    "actions": ["update"],
                    "after": {
                        "labels": {
                            "env": "dev",
                            "owner": "test-at-example-com"
                        }
                    }
                }
            }
        ]
    }
}

test_allow_with_all_labels if {
    count(deny) == 0 with input as {
        "resource_changes": [
            {
                "type": "google_project",
                "address": "google_project.test",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "labels": {
                            "env": "dev",
                            "owner": "test-at-example-com",
                            "app": "my-app"
                        }
                    }
                }
            }
        ]
    }
}

test_ignore_delete_action if {
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
