# agents/clc_local/executor.py
"""
CLC Local Executor — Core Execution Logic (v0.1)
"""
from __future__ import annotations
from typing import Dict, Any

from .policy import check_file_allowed
from .utils import write_file, apply_patch

def execute_task(spec: Dict[str, Any]) -> Dict[str, Any]:
    """
    Executes a structured task spec, applying operations to the local filesystem.
    """
    task_id = spec.get("task_id", "unknown-task")
    operations = spec.get("operations", [])

    files_touched = []
    errors = []
    ops_applied = 0
    
    print(f"--- Starting execution for task: {task_id} ---")

    for i, op in enumerate(operations):
        op_id = f"op_{i+1}"
        file_path = op.get("file")
        op_action = op.get("op")

        if not file_path or not op_action:
            errors.append({"op_id": op_id, "error": "Operation missing 'file' or 'op' field."})
            continue

        # 1. Writer Policy Check
        allowed, reason = check_file_allowed(file_path)
        if not allowed:
            errors.append({
                "op_id": op_id,
                "file": file_path,
                "error": f"Writer policy blocked: {reason}"
            })
            print(f"⚠️  Skipping operation on '{file_path}': Policy violation.")
            continue

        # 2. Execute Operation
        try:
            print(f"  Executing {op_action} on {file_path}...")
            if op_action == "write_file":
                write_file(file_path, op.get("content", ""))
                files_touched.append(file_path)
                ops_applied += 1

            elif op_action == "apply_patch":
                apply_patch(file_path, op.get("patch", ""))
                files_touched.append(file_path)
                ops_applied += 1
            
            # TODO: Add 'replace_snippet', 'create_dir', 'delete_file' operations

            else:
                errors.append({"op_id": op_id, "error": f"Unknown operation: '{op_action}'"})

        except Exception as e:
            errors.append({"op_id": op_id, "file": file_path, "error": str(e)})

    # 3. Determine Final Status
    status = "success"
    if errors:
        status = "partial" if ops_applied > 0 else "failed"

    print(f"--- Finished execution for task: {task_id} ---")
    
    # 4. Return Execution Result
    return {
        "task_id": task_id,
        "status": status,
        "summary": f"Execution finished. {ops_applied} operations applied, {len(errors)} errors.",
        "details": {
            "files_touched": list(set(files_touched)), # Unique list
            "ops_applied_count": ops_applied,
            "errors": errors,
        }
    }
