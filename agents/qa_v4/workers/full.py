"""
QA Worker Full Mode - Comprehensive quality assurance with all features.

Features:
- All Enhanced features
- 3-level status (pass/warning/fail)
- ArchitectSpec-driven checklist
- R&D feedback (full with categorization)
- 3-level lint fallback (ruff → flake8 → py_compile)
- Advanced pattern checks

Use for:
- High-risk domains (security, payment, auth)
- Explicit requirement: qa.mode: full
- Nightly/batch jobs (time budget available)
- Critical production changes
"""

import json
import os
import re
import sys
import py_compile
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

# Add project root to path
sys.path.insert(0, os.getcwd())

from agents.qa_v4.actions import QaActions
from agents.qa_v4.checklist_engine import evaluate_checklist
from agents.qa_v4.rnd_integration import send_to_rnd


class QAWorkerFull:
    """
    Full QA Worker with all features.
    
    Features beyond Enhanced:
    - 3-level status (pass/warning/fail)
    - ArchitectSpec-driven checklist evaluation
    - R&D feedback (full with categorization)
    - 3-level lint fallback (ruff → flake8 → py_compile)
    - Advanced pattern checks
    """
    
    def __init__(
        self,
        enable_lint: bool = True,
        enable_tests: bool = True,
        enable_security: bool = True,
        enable_rnd_feedback: bool = True,
    ):
        """
        Initialize Full QA Worker.
        
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

    def _run_lint_3level(self, file_path: str) -> Dict[str, Any]:
        """
        3-level lint fallback: ruff → flake8 → py_compile.
        
        Returns:
            Dict with success, method_used, output
        """
        # Level 1: Try ruff
        lint_res = self.actions.run_ruff(file_path)
        if lint_res["success"]:
            return {**lint_res, "method_used": "ruff"}
        
        # Level 2: Try flake8
        lint_res = self.actions.run_flake8(file_path)
        if lint_res["success"]:
            return {**lint_res, "method_used": "flake8"}
        
        # Level 3: Try py_compile (last resort)
        try:
            py_compile.compile(file_path, doraise=True)
            return {
                "success": True,
                "stdout": "Syntax check passed (py_compile)",
                "stderr": "",
                "exit_code": 0,
                "method_used": "py_compile"
            }
        except py_compile.PyCompileError as e:
            return {
                "success": False,
                "stdout": "",
                "stderr": str(e),
                "exit_code": 1,
                "method_used": "py_compile"
            }
        except Exception as e:
            return {
                "success": False,
                "stdout": "",
                "stderr": str(e),
                "exit_code": -1,
                "method_used": "py_compile"
            }

    def _categorize_issues(self, issues: List[str], warnings: List[str]) -> Dict[str, List[str]]:
        """
        Categorize issues and warnings for R&D feedback.
        
        Categories:
        - security: Security-related issues
        - lint: Linting issues
        - test: Test failures
        - structure: File/structure issues
        - other: Other issues
        """
        categories = {
            "security": [],
            "lint": [],
            "test": [],
            "structure": [],
            "other": []
        }
        
        all_items = [("issue", i) for i in issues] + [("warning", w) for w in warnings]
        
        for item_type, item in all_items:
            item_lower = item.lower()
            if "security" in item_lower or "api key" in item_lower or "password" in item_lower:
                categories["security"].append(f"{item_type}: {item}")
            elif "lint" in item_lower:
                categories["lint"].append(f"{item_type}: {item}")
            elif "test" in item_lower:
                categories["test"].append(f"{item_type}: {item}")
            elif "file" in item_lower or "not found" in item_lower:
                categories["structure"].append(f"{item_type}: {item}")
            else:
                categories["other"].append(f"{item_type}: {item}")
        
        return categories

    def _determine_status_3level(
        self,
        issues: List[str],
        warnings: List[str],
        checklist_result: Dict[str, Any]
    ) -> str:
        """
        Determine 3-level status: pass | warning | fail.
        
        Rules:
        - fail: Issues exist OR checklist failed
        - warning: Warnings exist (but no issues, checklist passed)
        - pass: No issues, no warnings, checklist passed
        """
        # Check checklist status first
        checklist_status = checklist_result.get("status", "pass")
        if checklist_status == "fail":
            return "fail"
        
        # Check for critical issues
        if issues:
            return "fail"
        
        # Check for warnings
        if warnings:
            return "warning"
        
        # All good
        return "pass"

    def process_task(self, task_data: Dict[str, Any]) -> Dict[str, Any]:
        task_id = task_data.get("task_id", "unknown")
        files_touched = task_data.get("files_touched", [])
        architect_spec = task_data.get("architect_spec", {})
        
        print(f"[QA Full] Processing task {task_id}...")
        
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
        warnings = []  # Non-critical warnings
        
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

            # Linting (3-level fallback: ruff → flake8 → py_compile)
            if self.enable_lint and f.endswith(".py"):
                lint_res = self._run_lint_3level(f)
                
                if not lint_res["success"]:
                    results["lint_success"] = False
                    issues.append(f"Lint failed for {f} (method: {lint_res.get('method_used', 'unknown')})")
                elif lint_res.get("stderr"):
                    # Non-critical lint warnings
                    warnings.append(f"Lint warning for {f} ({lint_res.get('method_used', 'unknown')}): {lint_res['stderr'][:100]}")
            
            # Testing
            if self.enable_tests and "test" in f and f.endswith(".py"):
                test_res = self.actions.run_pytest(f)
                if not test_res["success"]:
                    results["test_success"] = False
                    issues.append(f"Tests failed for {f}")
                elif test_res.get("stderr"):
                    warnings.append(f"Test warning for {f}: {test_res['stderr'][:100]}")

        # Pattern Checks (from ArchitectSpec)
        if architect_spec:
            patterns = architect_spec.get("architecture", {}).get("patterns", [])
            if patterns:
                pat_res = self.actions.run_pattern_check(files_touched, patterns)
                if pat_res["status"] == "failed":
                    results["pattern_issues"] = pat_res["issues"]
                    issues.extend(pat_res["issues"])

        # Evaluate Checklist (with ArchitectSpec support)
        checklist_result = evaluate_checklist(
            results,
            architect_spec=architect_spec,
            actions=self.actions if architect_spec else None
        )
        
        # Determine 3-level Status
        status = self._determine_status_3level(issues, warnings, checklist_result)
        
        result = {
            "task_id": task_id,
            "status": status,  # pass | warning | fail
            "checklist": checklist_result,
            "issues": issues,
            "warnings": warnings,
            "files_touched": files_touched,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "qa_mode": "full"
        }
        
        # R&D Feedback (full version with categorization)
        if self.enable_rnd_feedback:
            # Categorize issues and warnings
            categories = self._categorize_issues(issues, warnings)
            
            # Extract failed checks from checklist_result
            failed_checks = []
            if isinstance(checklist_result, dict):
                if "checklist" in checklist_result:
                    failed_checks = [k for k, v in checklist_result["checklist"].items() if not v]
                elif "failed_ids" in checklist_result:
                    failed_checks = checklist_result["failed_ids"]
            
            rnd_feedback = {
                "task_id": task_id,
                "feedback_type": "qa_result",
                "mode": "full",
                "status": status,
                "issues": issues,
                "warnings": warnings,
                "categories": categories,  # Full: categorized feedback
                "checks_failed": failed_checks,
                "checklist_status": checklist_result.get("status", "unknown")
            }
            result["rnd_feedback"] = rnd_feedback
            send_to_rnd(rnd_feedback)
        
        self._log_telemetry(result)
        return result

    def _log_telemetry(self, result: Dict[str, Any]):
        with open(self.telemetry_file, "a") as f:
            f.write(json.dumps(result) + "\n")
        print(f"[QA Full] Telemetry logged to {self.telemetry_file}")


def main():
    """CLI entry point."""
    if len(sys.argv) < 2:
        print("Usage: python full.py <input_json_file>")
        sys.exit(1)
        
    input_file = Path(sys.argv[1])
    if not input_file.exists():
        print(f"Error: Input file {input_file} not found")
        sys.exit(1)
        
    with open(input_file, "r") as f:
        task_data = json.load(f)
        
    worker = QAWorkerFull()
    result = worker.process_task(task_data)
    
    print(json.dumps(result, indent=2))
    
    if result["status"] == "fail":
        sys.exit(1)


if __name__ == "__main__":
    main()
