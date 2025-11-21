# bridge/tools/dispatch_to_bridge.py
"""
Dispatches a GMX task_spec to the correct bridge inbox by generating a
formatted and secure Work Order (WO) YAML file.
"""
from __future__ import annotations

import yaml
import time
import uuid
from pathlib import Path
from typing import Dict, Any

# --- CONFIGURATION ---
# Assumes this script is run from a context where Path.home() is appropriate.
# The root directory is derived to ensure paths are secure.
try:
    # Anchor path to this file's location for robustness
    SCRIPT_DIR = Path(__file__).parent.resolve()
    # Assumes structure is /bridge/tools/
    ROOT_DIR = SCRIPT_DIR.parents[1]
    INBOX_DIR = ROOT_DIR / "bridge" / "inbox"
except IndexError:
    # Fallback for when the script is not in the expected location
    print("Warning: Could not derive project root from script path. Falling back to HOME_DIR.")
    ROOT_DIR = Path.home() / "02luka" # [FIX] Corrected from "02luka_local_g"
    INBOX_DIR = ROOT_DIR / "bridge" / "inbox"


# --- WO Structure and Formatting ---

def _generate_wo_filename(source: str, intent: str) -> str:
    """Generates a secure and trackable Work Order filename."""
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    short_uuid = str(uuid.uuid4())[:8]
    
    safe_source = "".join(c for c in source if c.isalnum() or c in ('-', '_')).rstrip()
    safe_intent = "".join(c for c in intent if c.isalnum() or c in ('-', '_')).rstrip()
    
    return f"WO-{timestamp}-{safe_source}-{safe_intent}-{short_uuid}.yaml"

def _format_wo_yaml(task_spec: Dict[str, Any], wo_id: str) -> str:
    """
    Formats the final Work Order YAML structure to be compatible with handlers.
    
    [CRITICAL FIX] This now produces a flat structure that gemini_handler.py expects.
    """
    wo_structure = {
        "wo_id": wo_id,
        "task_type": task_spec.get("intent"),
        "input": {
            "instructions": task_spec.get("description", ""),
            "target_files": task_spec.get("target_files", []),
            "command": task_spec.get("command"),
            "context": task_spec.get("context", {})
        }
    }
    return yaml.dump(wo_structure, indent=2, sort_keys=False, default_flow_style=False)


# --- Primary Dispatch Function ---

def dispatch_work_order(task_spec: Dict[str, Any], source: str = 'gmx') -> Path:
    """
    Routes the task_spec to the correct inbox and writes the Work Order YAML file.

    Args:
        task_spec: The standardized task_spec dictionary.
        source: The source agent of the task (e.g., 'gmx_cli').
        
    Returns:
        The Path object of the created YAML file.
    
    Raises:
        PermissionError: If the resolved write path is outside the allowed INBOX_DIR.
        ValueError: If the task_spec is invalid or routing fails.
    """
    intent = task_spec.get("intent")
    if not intent:
        raise ValueError("task_spec must contain an 'intent' field for routing.")

    # Routing Logic: Determine the correct agent inbox.
    if intent in ["run-command", "analyze"]:
        target_inbox_name = "GEMINI"
    else:  # refactor, fix-bug, add-feature, generate-file, etc.
        target_inbox_name = "LIAM"

    # [CRITICAL FIX] Ensure the target-specific inbox directory exists.
    target_inbox_path = INBOX_DIR / target_inbox_name
    target_inbox_path.mkdir(parents=True, exist_ok=True)
    
    # 1. Generate filename and final path
    filename = _generate_wo_filename(source, intent)
    wo_id = Path(filename).stem
    target_file = target_inbox_path / filename
    
    # 2. Security Check: Ensure the path is within the allowed root inbox directory.
    # Using `is_relative_to` is a more robust check than string comparison.
    if not target_file.resolve().is_relative_to(INBOX_DIR.resolve()):
        raise PermissionError(f"Security violation: Attempted write path '{target_file}' is outside safe inbox '{INBOX_DIR}'.")

    # 3. Format and write the YAML content
    yaml_content = _format_wo_yaml(task_spec, wo_id)
    
    try:
        target_file.write_text(yaml_content, encoding='utf-8')
    except Exception as e:
        # Wrap specific exceptions if needed, but RuntimeError is a decent catch-all.
        raise RuntimeError(f"Failed to write Work Order file to {target_file}: {e!r}")

    print(f"Work Order '{wo_id}' dispatched to {target_inbox_name}: {target_file.name}")
    return target_file

# --- Example Usage ---
if __name__ == "__main__":
    print(f"Project Root derived as: {ROOT_DIR}")
    print(f"Secure Inbox Path: {INBOX_DIR}")
    
    # Example task for the LIAM worker
    test_task_refactor = {
        "intent": "refactor",
        "description": "Test refactor task for the policy loader.",
        "target_files": ["governance/policy_loader.py"],
        "context": {"complexity": "medium"}
    }
    
    # Example task for the GEMINI handler
    test_task_command = {
        "intent": "run-command",
        "description": "Safely remove an unused Docker volume.",
        "command": "docker volume rm my_test_volume",
        "context": {"reason": "Cleanup of experimental resources."}
    }
    
    try:
        print("\n--- Dispatching refactor task to LIAM ---")
        liam_wo_path = dispatch_work_order(test_task_refactor, source='manual_test')
        print(f"Content of {liam_wo_path.name}:\n---\n{liam_wo_path.read_text(encoding='utf-8')}---")

        print("\n--- Dispatching run-command task to GEMINI ---")
        gemini_wo_path = dispatch_work_order(test_task_command, source='manual_test')
        print(f"Content of {gemini_wo_path.name}:\n---\n{gemini_wo_path.read_text(encoding='utf-8')}---")
        
    except (ValueError, PermissionError, RuntimeError) as e:
        print(f"\nERROR during test dispatch: {e}")
