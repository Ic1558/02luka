"""
QA actions for lightweight quality checks (no new deps).
"""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Dict, List


def run_py_compile(targets: List[str]) -> Dict:
    """
    Run python -m py_compile over provided targets.
    """
    for target in targets:
        try:
            subprocess.run(
                ["python", "-m", "py_compile", target],
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as exc:
            return {
                "status": "failed",
                "reason": "LINT_FAILED",
                "exit_code": exc.returncode,
                "stderr": exc.stderr[-500:] if exc.stderr else "",
            }
        except FileNotFoundError:
            return {"status": "failed", "reason": "PYTHON_NOT_FOUND"}
    return {"status": "success"}


def run_pytest(target: str) -> Dict:
    """
    Run pytest on a target path.
    """
    try:
        completed = subprocess.run(
            ["python", "-m", "pytest", target],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return {"status": "failed", "reason": "PYTHON_NOT_FOUND"}

    if completed.returncode != 0:
        return {
            "status": "failed",
            "reason": "TEST_FAILED",
            "exit_code": completed.returncode,
            "stderr": (completed.stderr or "")[-500:],
            "stdout": (completed.stdout or "")[-500:],
        }

    return {
        "status": "success",
        "exit_code": completed.returncode,
        "stdout": (completed.stdout or "")[-500:],
    }


class QaActions:
    """
    Thin wrapper to allow easy mocking in tests.
    """

    def run_lint(self, targets: List[str]) -> Dict:
        return run_py_compile(targets)

    def run_tests(self, target: str) -> Dict:
        return run_pytest(target)


__all__ = ["QaActions", "run_py_compile", "run_pytest"]
