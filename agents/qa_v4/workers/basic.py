"""
QA Worker Basic Mode - Fast, lightweight quality assurance.

Features:
- Real linting (ruff/flake8)
- Test execution (pytest)
- Pattern-based QA checks
- Security basics check
- Checklist evaluation from ArchitectSpec
- R&D Lane integration (pattern feedback)

This is the default Basic mode for routine tasks.
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

# Add project root to path
sys.path.insert(0, os.getcwd())

from agents.qa_v4.actions import QaActions
from agents.qa_v4.checklist_engine import evaluate_checklist
from agents.qa_v4.rnd_integration import send_to_rnd


class QAWorkerBasic:
    """
    Basic QA Worker - Fast, lightweight quality checks.
    
    Use for:
    - Dev loop (interactive development)
    - Low-risk features
    - Small file changes (<3 files)
    - Non-critical domains
    """
    
    def __init__(self):
        self.telemetry_file = Path("g/telemetry/qa_lane_execution.jsonl")
        self.telemetry_file.parent.mkdir(parents=True, exist_ok=True)
        self.actions = QaActions()

    def process_task(self, task_data: Dict[str, Any]) -> Dict[str, Any]:
        task_id = task_data.get("task_id", "unknown")
        files_touched = task_data.get("files_touched", [])
        architect_spec = task_data.get("architect_spec", {})
        
        print(f"[QA Basic] Processing task {task_id}...")
        
        results = {
            "files_exist": True,
            "lint_success": True,
            "test_success": True,
            "security_issues": [],
            "pattern_issues": []
        }
        issues = []
        
        # 1. File Existence & Security
        for f in files_touched:
            path = Path(f)
            if not path.exists():
                results["files_exist"] = False
                issues.append(f"File not found: {f}")
                continue
                
            # Security
            sec_issues = self.actions.check_security_basics(f)
            if sec_issues:
                results["security_issues"].extend([f"{f}: {i}" for i in sec_issues])
                issues.extend([f"Security: {f}: {i}" for i in sec_issues])

            # Linting (Try Ruff, fallback Flake8)
            # Only lint python files
            if f.endswith(".py"):
                lint_res = self.actions.run_ruff(f)
                if not lint_res["success"]:
                    # Fallback
                    lint_res = self.actions.run_flake8(f)
                
                if not lint_res["success"]:
                    results["lint_success"] = False
                    issues.append(f"Lint failed for {f}")
            
            # Testing
            # If file is a test file, run it
            if "test" in f and f.endswith(".py"):
                test_res = self.actions.run_pytest(f)
                if not test_res["success"]:
                    results["test_success"] = False
                    issues.append(f"Tests failed for {f}")

        # Pattern Checks (from ArchitectSpec)
        if architect_spec:
            patterns = architect_spec.get("architecture", {}).get("patterns", [])
            if patterns:
                pat_res = self.actions.run_pattern_check(files_touched, patterns)
                if pat_res["status"] == "failed":
                    results["pattern_issues"] = pat_res["issues"]
                    issues.extend(pat_res["issues"])

        # Evaluate Checklist
        checklist_result = evaluate_checklist(results)
        
        # Determine Status
        status = "pass"
        if isinstance(checklist_result, dict) and "status" in checklist_result:
             status = checklist_result["status"]
        else:
             # Fallback for simple dict
             status = "pass" if all(checklist_result.values()) else "fail"
        
        result = {
            "task_id": task_id,
            "status": status,
            "checklist": checklist_result,
            "issues": issues,
            "files_touched": files_touched,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "qa_mode": "basic"
        }
        
        # R&D Feedback
        if status == "fail":
            # Extract failed checks from checklist_result
            failed_checks = []
            if isinstance(checklist_result, dict):
                if "checklist" in checklist_result:
                    # checklist_result has nested "checklist" dict
                    failed_checks = [k for k, v in checklist_result["checklist"].items() if not v]
                elif "failed_ids" in checklist_result:
                    # checklist_result has "failed_ids" list
                    failed_checks = checklist_result["failed_ids"]
            
            rnd_feedback = {
                "task_id": task_id,
                "feedback_type": "qa_failure",
                "issues": issues,
                "checks_failed": failed_checks
            }
            result["rnd_feedback"] = rnd_feedback
            send_to_rnd(rnd_feedback)
        
        self._log_telemetry(result)
        return result

    def _log_telemetry(self, result: Dict[str, Any]):
        with open(self.telemetry_file, "a") as f:
            f.write(json.dumps(result) + "\n")
        print(f"[QA Basic] Telemetry logged to {self.telemetry_file}")


def main():
    """CLI entry point."""
    if len(sys.argv) < 2:
        print("Usage: python basic.py <input_json_file>")
        sys.exit(1)
        
    input_file = Path(sys.argv[1])
    if not input_file.exists():
        print(f"Error: Input file {input_file} not found")
        sys.exit(1)
        
    with open(input_file, "r") as f:
        task_data = json.load(f)
        
    worker = QAWorkerBasic()
    result = worker.process_task(task_data)
    
    print(json.dumps(result, indent=2))
    
    if result["status"] != "pass":
        sys.exit(1)


if __name__ == "__main__":
    main()
