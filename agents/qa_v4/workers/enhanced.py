"""
QA Worker Enhanced Mode - Comprehensive quality assurance.

Features:
- All Basic features
- Warnings tracking (separate from issues)
- Enhanced security (8 patterns)
- Batch file processing
- Configurable flags (enable_lint, enable_tests, enable_security, enable_rnd_feedback)
- R&D feedback (light version)

Use for:
- Medium/high risk work orders
- Modules with recent QA failures
- Production-critical paths
- Security-sensitive domains
"""

import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

# Add project root to path
sys.path.insert(0, os.getcwd())

from agents.qa_v4.actions import QaActions
from agents.qa_v4.checklist_engine import evaluate_checklist
from agents.qa_v4.rnd_integration import send_to_rnd


class QAWorkerEnhanced:
    """
    Enhanced QA Worker with warnings and batch support.
    
    Features beyond Basic:
    - Warnings tracking (separate from critical issues)
    - Enhanced security patterns (8 vs 6)
    - Batch file processing
    - Configurable checks
    - R&D feedback (light version)
    """
    
    def __init__(
        self,
        enable_lint: bool = True,
        enable_tests: bool = True,
        enable_security: bool = True,
        enable_rnd_feedback: bool = True,
    ):
        """
        Initialize Enhanced QA Worker.
        
        Args:
            enable_lint: Enable linting checks
            enable_tests: Enable test execution
            enable_security: Enable security pattern checks
            enable_rnd_feedback: Enable R&D feedback on issues
        """
        self.telemetry_file = Path("g/telemetry/qa_lane_execution.jsonl")
        self.telemetry_file.parent.mkdir(parents=True, exist_ok=True)
        self.actions = QaActions()
        self.enable_lint = enable_lint
        self.enable_tests = enable_tests
        self.enable_security = enable_security
        self.enable_rnd_feedback = enable_rnd_feedback

    def _check_security_enhanced(self, file_path: str) -> List[str]:
        """
        Enhanced security check with 8 patterns.
        
        Patterns:
        1. API keys (sk-*)
        2. Hardcoded passwords
        3. Hardcoded API keys
        4. Hardcoded secrets
        5. eval() usage
        6. exec() usage
        7. os.system() usage
        8. subprocess with shell=True
        """
        issues = []
        patterns = [
            (r"sk-[a-zA-Z0-9]{20,}", "Potential API Key found (sk-*)"),
            (r"password\s*=\s*['\"][^'\"]+['\"]", "Hardcoded password found"),
            (r"api_key\s*=\s*['\"][^'\"]+['\"]", "Hardcoded API key found"),
            (r"secret\s*=\s*['\"][^'\"]+['\"]", "Hardcoded secret found"),
            (r"eval\(", "Use of eval() detected"),
            (r"exec\(", "Use of exec() detected"),
            (r"os\.system\(", "Use of os.system() detected"),
            (r"subprocess\.(call|run|Popen)\(.*shell\s*=\s*True", "subprocess with shell=True detected"),
        ]
        
        try:
            content = Path(file_path).read_text()
            for pat, msg in patterns:
                if re.search(pat, content):
                    issues.append(msg)
        except Exception:
            pass
        
        return issues

    def process_task(self, task_data: Dict[str, Any]) -> Dict[str, Any]:
        task_id = task_data.get("task_id", "unknown")
        files_touched = task_data.get("files_touched", [])
        architect_spec = task_data.get("architect_spec", {})
        
        print(f"[QA Enhanced] Processing task {task_id}...")
        
        # Handle batch files (support both string and list)
        if isinstance(files_touched, str):
            files_touched = [files_touched]
        
        results = {
            "files_exist": True,
            "lint_success": True,
            "test_success": True,
            "security_issues": [],
            "pattern_issues": []
        }
        issues = []  # Critical issues
        warnings = []  # Non-critical warnings (separate from issues)
        
        # 1. File Existence & Security
        for f in files_touched:
            path = Path(f)
            if not path.exists():
                results["files_exist"] = False
                issues.append(f"File not found: {f}")
                continue
                
            # Enhanced Security (8 patterns)
            if self.enable_security:
                sec_issues = self._check_security_enhanced(f)
                if sec_issues:
                    results["security_issues"].extend([f"{f}: {i}" for i in sec_issues])
                    issues.extend([f"Security: {f}: {i}" for i in sec_issues])

            # Linting (Try Ruff, fallback Flake8)
            if self.enable_lint and f.endswith(".py"):
                lint_res = self.actions.run_ruff(f)
                if not lint_res["success"]:
                    # Fallback
                    lint_res = self.actions.run_flake8(f)
                
                if not lint_res["success"]:
                    results["lint_success"] = False
                    issues.append(f"Lint failed for {f}")
                elif lint_res.get("stderr"):
                    # Non-critical lint warnings
                    warnings.append(f"Lint warning for {f}: {lint_res['stderr'][:100]}")
            
            # Testing
            if self.enable_tests and "test" in f and f.endswith(".py"):
                test_res = self.actions.run_pytest(f)
                if not test_res["success"]:
                    results["test_success"] = False
                    issues.append(f"Tests failed for {f}")
                elif test_res.get("stderr"):
                    # Non-critical test warnings
                    warnings.append(f"Test warning for {f}: {test_res['stderr'][:100]}")

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
        
        # Determine Status (still pass/fail, but track warnings separately)
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
            "warnings": warnings,  # Enhanced: separate warnings
            "files_touched": files_touched,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "qa_mode": "enhanced"
        }
        
        # R&D Feedback (light version - only on failures)
        if self.enable_rnd_feedback and status == "fail":
            # Extract failed checks from checklist_result
            failed_checks = []
            if isinstance(checklist_result, dict):
                if "checklist" in checklist_result:
                    failed_checks = [k for k, v in checklist_result["checklist"].items() if not v]
                elif "failed_ids" in checklist_result:
                    failed_checks = checklist_result["failed_ids"]
            
            rnd_feedback = {
                "task_id": task_id,
                "feedback_type": "qa_failure",
                "mode": "enhanced",
                "issues": issues,
                "warnings": warnings,  # Include warnings in feedback
                "checks_failed": failed_checks
            }
            result["rnd_feedback"] = rnd_feedback
            send_to_rnd(rnd_feedback)
        
        self._log_telemetry(result)
        return result

    def _log_telemetry(self, result: Dict[str, Any]):
        with open(self.telemetry_file, "a") as f:
            f.write(json.dumps(result) + "\n")
        print(f"[QA Enhanced] Telemetry logged to {self.telemetry_file}")


def main():
    """CLI entry point."""
    if len(sys.argv) < 2:
        print("Usage: python enhanced.py <input_json_file>")
        sys.exit(1)
        
    input_file = Path(sys.argv[1])
    if not input_file.exists():
        print(f"Error: Input file {input_file} not found")
        sys.exit(1)
        
    with open(input_file, "r") as f:
        task_data = json.load(f)
        
    worker = QAWorkerEnhanced()
    result = worker.process_task(task_data)
    
    print(json.dumps(result, indent=2))
    
    if result["status"] != "pass":
        sys.exit(1)


if __name__ == "__main__":
    main()
