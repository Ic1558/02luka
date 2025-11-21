# agents/gmx_cli/validator.py
"""
Governance and safety validator for GMX plans.
"""
from __future__ import annotations
from typing import Dict, Any, List

# List of forbidden paths for GMX to modify.
FORBIDDEN_PATHS = [
    "apps/mls/",
    ".git/",
    "bridge/",
    "g/ledger/",
]

def validate_plan(plan: Dict[str, Any]) -> List[str]:
    """
    Validates a GMX plan against governance rules.
    Returns a list of validation error strings. If the list is empty, validation passed.
    """
    errors = []
    task_spec = plan.get("task_spec", {})
    target_files = task_spec.get("target_files", [])

    for file_path in target_files:
        if any(file_path.startswith(forbidden) for forbidden in FORBIDDEN_PATHS):
            errors.append(f"Validation Error: Modification of forbidden path '{file_path}' is not allowed.")
    
    # TODO: Add more validation rules (e.g., check for dangerous shell commands).
    return errors