#!/usr/bin/env python3
"""
FDE Validator (v1.0)
Enforces V4 lifecycle rules defined in fde_rules.json.

Usage:
    python fde_validator.py --action <action> --path <path> [--context <json>]

Returns:
    JSON: {"allowed": bool, "reason": str, "rule_id": str, "details": dict}
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, Any, Optional

# Constants
REPO_ROOT = Path(__file__).resolve().parents[3] # g/core/fde/ -> repo root
RULES_PATH = Path(__file__).parent / "fde_rules.json"

def load_rules() -> Dict[str, Any]:
    if not RULES_PATH.exists():
        # Fallback/Error if rules missing
        return {}
    with open(RULES_PATH, "r") as f:
        return json.load(f)

def check_legacy_zone(path_str: str, rules: Dict[str, Any]) -> Optional[str]:
    """Check if path is in a forbidden legacy zone."""
    zone_rules = rules.get("rules", {}).get("legacy_zone_protection", {})
    if not zone_rules:
        return None
        
    forbidden = zone_rules.get("forbidden_paths", [])
    # Normalize path for check
    norm_path = os.path.normpath(path_str)
    norm_parts = norm_path.split(os.sep)
    
    for bad_path in forbidden:
        # Simple substring check for now, can be regex later
        # Remove leading/trailing slashes for cleaner matching
        clean_bad = bad_path.strip("/")
        
        # If rule is path segment
        if clean_bad in norm_parts:
             return f"Path contains forbidden segment '{clean_bad}'"
             
        # Fallback for longer paths (e.g. full file paths)
        if clean_bad in norm_path:
             return f"Path contains forbidden segment '{clean_bad}'"
    return None

def check_feature_dev(path_str: str, rules: Dict[str, Any]) -> Optional[str]:
    """Check if feature dev work has required spec/plan."""
    feat_rules = rules.get("rules", {}).get("feature_development", {})
    if not feat_rules:
        return None

    # Only applies to feature-dev paths
    pattern = feat_rules.get("artifact_location_pattern", "g/reports/feature-dev/{feature_name}/")
    base_pattern = pattern.split("{")[0] # e.g. "g/reports/feature-dev/"
    
    if base_pattern not in path_str:
        return None # Not a feature dev path, so rule doesn't apply
        
    # Extract feature directory
    try:
        # path: .../g/reports/feature-dev/my-feature/some_file.py
        # relative: my-feature/some_file.py
        rel_path = path_str.split(base_pattern)[1]
        feature_name = rel_path.split("/")[0]
        
        if not feature_name:
            return None
            
        feature_dir = Path(base_pattern) / feature_name
        
        # Check for artifacts
        required = feat_rules.get("required_artifacts", [])
        missing = []
        
        # This is a "soft" check - it checks if they EXIST on disk.
        # If we are creating the spec itself, we shouldn't block.
        # Exception: if the file being written IS one of the artifacts, allow it.
        
        filename = os.path.basename(path_str)
        
        # Naive check: if writing a spec/plan, allow it.
        if "spec" in filename or "plan" in filename:
            return None
            
        # Otherwise, check if artifacts exist in the dir
        # We need to resolve the absolute path to check existence
        # Use REPO_ROOT instead of cwd
        abs_feature_dir = REPO_ROOT / feature_dir
        
        if not abs_feature_dir.exists():
             return f"Feature directory {feature_dir} does not exist. Create spec/plan first."

        # Check for spec and plan existence (glob)
        # Match our real naming convention:
        #   251121_auto_clean_logs_spec_v01.md
        #   251121_auto_clean_logs_plan_v01.md
        has_spec = list(abs_feature_dir.glob("*_spec_v*.md"))
        has_plan = list(abs_feature_dir.glob("*_plan_v*.md"))
        
        if not has_spec:
            missing.append("spec_v*.md")
        if not has_plan:
            missing.append("plan_v*.md")
            
        if missing:
            return f"Missing required artifacts in {feature_dir}: {', '.join(missing)}"
            
    except IndexError:
        return None
        
    return None

def validate(action: str, path: str, context: Dict[str, Any]) -> Dict[str, Any]:
    rules = load_rules()
    
    # 1. Legacy Zone Protection
    if action in ["write", "delete", "move"]:
        fail_reason = check_legacy_zone(path, rules)
        if fail_reason:
            return {
                "allowed": False,
                "reason": fail_reason,
                "rule_id": "legacy_zone_protection"
            }

    # 2. Feature Dev Enforcement
    if action in ["write"]:
        fail_reason = check_feature_dev(path, rules)
        if fail_reason:
             return {
                "allowed": False,
                "reason": fail_reason,
                "rule_id": "feature_development"
            }
            
    # 3. Main Branch Protection (Placeholder for git hook)
    if action == "commit":
         mb_rules = rules.get("rules", {}).get("main_branch_protection", {})
         if not mb_rules.get("allow_direct_commit", True):
             # In a real hook, we'd check the branch name from context
             branch = context.get("branch", "")
             if branch == "main":
                 return {
                     "allowed": False,
                     "reason": "Direct commits to main are disabled.",
                     "rule_id": "main_branch_protection"
                 }

    return {"allowed": True, "reason": "No rules violated", "rule_id": None}

def main():
    parser = argparse.ArgumentParser(description="FDE Validator")
    parser.add_argument("--action", required=True, help="Action type (write, delete, commit)")
    parser.add_argument("--path", required=True, help="Target file path")
    parser.add_argument("--context", default="{}", help="JSON context string")
    
    args = parser.parse_args()
    
    try:
        context = json.loads(args.context)
    except json.JSONDecodeError:
        context = {}
        
    result = validate(args.action, args.path, context)
    print(json.dumps(result, indent=2))
    
    if not result["allowed"]:
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
