"""
QA Worker Factory - Central factory for QA workers (3-mode system).

This is the *only* place that should know how to map mode -> worker class.

Usage:
    # Simple mode-based creation
    worker = QAWorkerFactory.create("enhanced")
    
    # Intelligent mode selection from task data
    result = QAWorkerFactory.create_for_task(task_data)
    worker = result["worker"]
    mode = result["mode"]
    reason = result["reason"]
"""

import sys
from typing import Any, Dict, Optional

# Add project root to path
import os
sys.path.insert(0, os.getcwd())

from agents.qa_v4.workers import QAWorkerBasic, QAWorkerEnhanced, QAWorkerFull
from agents.qa_v4.mode_selector import select_qa_mode, get_mode_selection_reason

# Import guardrails (with fallback)
try:
    from agents.qa_v4.guardrails import get_guardrails
except ImportError:
    def get_guardrails():
        return None


class QAWorkerFactory:
    """
    Central factory for QA workers (3-mode system).
    
    This is the *only* place that should know how to map mode -> worker class.
    If we add "Ultra" or "Lite" modes in the future, only this file needs to change.
    """
    
    @staticmethod
    def create(mode: str = "basic") -> Any:
        """
        Create QA worker for specified mode.
        
        Args:
            mode: "basic" | "enhanced" | "full" (case-insensitive)
        
        Returns:
            QA worker instance (QAWorkerBasic, QAWorkerEnhanced, or QAWorkerFull)
        
        Note:
            Unknown modes fallback to "basic" (no exception thrown)
        """
        mode_norm = (mode or "basic").lower().strip()
        
        # Guardrail: Unknown mode → fallback to basic
        if mode_norm not in ("basic", "enhanced", "full"):
            print(
                f"[QA Factory] Unknown mode={mode!r}, fallback to 'basic'",
                file=sys.stderr
            )
            mode_norm = "basic"
        
        # Map mode to worker class
        if mode_norm == "basic":
            return QAWorkerBasic()
        elif mode_norm == "enhanced":
            return QAWorkerEnhanced()
        elif mode_norm == "full":
            return QAWorkerFull()
        else:
            # Final fallback (should never reach here)
            return QAWorkerBasic()
    
    @staticmethod
    def create_for_task(task_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Decide mode from task_data (risk/spec/history/env) and
        return both worker instance and decision metadata.
        
        Args:
            task_data: Task data dict with:
                - task_id: Task identifier
                - lane: Lane name
                - risk: Risk dict (level, domain)
                - qa: QA config dict (mode override)
                - files_touched: List of files
                - architect_spec: ArchitectSpec dict
                - dev_result: Dev worker result (optional)
                - history: History data (optional)
                - env: Environment dict (optional)
        
        Returns:
            {
                "worker": QA worker instance,
                "mode": Selected mode ("basic" | "enhanced" | "full"),
                "reason": Human-readable reason string
            }
        """
        # 1) Extract context for mode selector
        wo_spec = {
            "risk": task_data.get("risk", {}),
            "qa": task_data.get("qa", {}),
        }
        
        requirement = task_data.get("architect_spec", {})
        if requirement:
            # ArchitectSpec might have qa config
            requirement = requirement.get("qa", {}) or requirement
        
        dev_result = {
            "files_touched": task_data.get("files_touched", []),
            "lines_of_code": task_data.get("lines_of_code", 0),
        }
        
        # Merge dev_result if provided
        if "dev_result" in task_data:
            dev_result.update(task_data["dev_result"])
        
        history = task_data.get("history", {})
        env = task_data.get("env", {})
        
        # 2) Let mode_selector decide
        mode = select_qa_mode(
            wo_spec=wo_spec,
            requirement=requirement,
            dev_result=dev_result,
            history=history,
            env=env,
        )
        
        reason = get_mode_selection_reason(
            mode=mode,
            wo_spec=wo_spec,
            requirement=requirement,
            dev_result=dev_result,
            history=history,
            env=env,
        )
        
        # 3) Create worker according to selected mode
        worker = QAWorkerFactory.create(mode)
        
        # 4) Record usage in guardrails (for budget tracking)
        guardrails = get_guardrails()
        if guardrails:
            guardrails.record_usage(mode)
        
        # 5) Return worker + metadata (for logging/telemetry)
        return {
            "worker": worker,
            "mode": mode,
            "reason": reason,
        }


def create_qa_worker(mode: Optional[str] = None) -> Any:
    """
    Simple helper for callers that already know the mode.
    
    Args:
        mode: "basic" | "enhanced" | "full" (optional, defaults to "basic")
    
    Returns:
        QA worker instance
    """
    return QAWorkerFactory.create(mode or "basic")


def create_worker_for_task(task_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Shortcut for callers from dev / qa_handoff without importing the class.
    
    Args:
        task_data: Task data dict (see QAWorkerFactory.create_for_task)
    
    Returns:
        {
            "worker": QA worker instance,
            "mode": Selected mode,
            "reason": Selection reason
        }
    """
    return QAWorkerFactory.create_for_task(task_data)


__all__ = [
    "QAWorkerFactory",
    "create_qa_worker",
    "create_worker_for_task",
]
