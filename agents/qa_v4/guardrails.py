"""
QA Mode Guardrails.

Prevents mode abuse and ensures performance.
"""

import json
import os
from pathlib import Path
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Optional, Tuple


class QAModeGuardrails:
    """
    Guardrails for QA mode selection.
    
    Features:
    - Daily budget limits (full/enhanced modes)
    - Cooldown periods for mode upgrades
    - Performance monitoring and auto-degrade
    """
    
    def __init__(self, budget_file: Optional[Path] = None):
        """
        Initialize guardrails.
        
        Args:
            budget_file: Optional path to budget file (default: g/data/qa_mode_budget.json)
        """
        if budget_file is None:
            budget_file = Path("g/data/qa_mode_budget.json")
        
        self.budget_file = budget_file
        self.budget_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Daily limits (configurable via env)
        self.limits = {
            "full": int(os.getenv("QA_MODE_BUDGET_FULL", "10")),
            "enhanced": int(os.getenv("QA_MODE_BUDGET_ENHANCED", "50")),
            "basic": -1,  # Unlimited
        }
        
        # Performance thresholds (seconds)
        self.performance_thresholds = {
            "full": float(os.getenv("QA_MODE_LATENCY_THRESHOLD_FULL", "30.0")),
            "enhanced": float(os.getenv("QA_MODE_LATENCY_THRESHOLD_ENHANCED", "15.0")),
            "basic": float(os.getenv("QA_MODE_LATENCY_THRESHOLD_BASIC", "5.0")),
        }
        
        # Cooldown period (minutes) after failures
        self.cooldown_minutes = int(os.getenv("QA_MODE_COOLDOWN_MINUTES", "30"))
    
    def check_budget(self, mode: str) -> Tuple[bool, Optional[str]]:
        """
        Check if mode is within budget.
        
        Args:
            mode: QA mode to check (basic/enhanced/full)
        
        Returns:
            (allowed, reason) - reason is None if allowed, error message if not
        """
        if mode == "basic":
            return True, None
        
        # Load budget
        budget = self._load_budget()
        today = datetime.now(timezone.utc).date().isoformat()
        
        if today not in budget:
            budget[today] = {"full": 0, "enhanced": 0}
        
        count = budget[today].get(mode, 0)
        limit = self.limits.get(mode, 0)
        
        if limit > 0 and count >= limit:
            return False, f"{mode} mode budget exceeded ({count}/{limit} today)"
        
        return True, None
    
    def record_usage(self, mode: str) -> None:
        """
        Record mode usage (increment budget counter).
        
        Args:
            mode: QA mode that was used
        """
        if mode == "basic":
            return
        
        budget = self._load_budget()
        today = datetime.now(timezone.utc).date().isoformat()
        
        if today not in budget:
            budget[today] = {"full": 0, "enhanced": 0}
        
        budget[today][mode] = budget[today].get(mode, 0) + 1
        
        # Clean old entries (keep last 7 days)
        cutoff = (datetime.now(timezone.utc) - timedelta(days=7)).date().isoformat()
        budget = {k: v for k, v in budget.items() if k >= cutoff}
        
        try:
            with open(self.budget_file, "w") as f:
                json.dump(budget, f, indent=2)
        except Exception as e:
            # Silent failure - don't break QA if budget file write fails
            print(f"[QA Guardrails] Warning: Failed to write budget: {e}", file=os.sys.stderr)
    
    def check_cooldown(self, module: str, recent_failures: int = 0) -> Tuple[bool, Optional[str]]:
        """
        Check if module should be in cooldown (recent failures).
        
        Args:
            module: Module name/path
            recent_failures: Number of recent QA failures (from history)
        
        Returns:
            (should_upgrade, reason) - True if should upgrade mode due to failures
        """
        # If module has recent failures, suggest enhanced/full
        if recent_failures >= 2:
            return True, f"Module has {recent_failures} recent QA failures, suggest enhanced mode"
        
        return False, None
    
    def check_performance(self, mode: str, latency_seconds: float) -> Tuple[bool, Optional[str]]:
        """
        Check if mode performance is acceptable.
        
        Args:
            mode: QA mode that was used
            latency_seconds: Execution time in seconds
        
        Returns:
            (acceptable, reason) - False if latency exceeds threshold
        """
        threshold = self.performance_thresholds.get(mode, float("inf"))
        
        if latency_seconds > threshold:
            return False, f"{mode} mode latency {latency_seconds:.1f}s exceeds threshold {threshold:.1f}s"
        
        return True, None
    
    def get_degraded_mode(self, mode: str) -> str:
        """
        Get next lower mode for degradation.
        
        Args:
            mode: Current mode
        
        Returns:
            Degraded mode (full -> enhanced -> basic)
        """
        if mode == "full":
            return "enhanced"
        elif mode == "enhanced":
            return "basic"
        else:
            return "basic"  # Already at lowest
    
    def _load_budget(self) -> Dict[str, Any]:
        """
        Load budget from file.
        
        Returns:
            Budget dictionary (date -> mode -> count)
        """
        if not self.budget_file.exists():
            return {}
        
        try:
            with open(self.budget_file, "r") as f:
                return json.load(f)
        except Exception as e:
            # Silent failure - return empty budget
            print(f"[QA Guardrails] Warning: Failed to load budget: {e}", file=os.sys.stderr)
            return {}
    
    def get_budget_status(self) -> Dict[str, Any]:
        """
        Get current budget status.
        
        Returns:
            Dictionary with today's usage and limits
        """
        budget = self._load_budget()
        today = datetime.now(timezone.utc).date().isoformat()
        
        today_budget = budget.get(today, {"full": 0, "enhanced": 0})
        
        return {
            "date": today,
            "full": {
                "used": today_budget.get("full", 0),
                "limit": self.limits["full"],
                "remaining": max(0, self.limits["full"] - today_budget.get("full", 0)),
            },
            "enhanced": {
                "used": today_budget.get("enhanced", 0),
                "limit": self.limits["enhanced"],
                "remaining": max(0, self.limits["enhanced"] - today_budget.get("enhanced", 0)),
            },
            "basic": {
                "used": -1,  # Unlimited
                "limit": -1,
                "remaining": -1,
            },
        }


# Global instance (singleton pattern)
_guardrails_instance: Optional[QAModeGuardrails] = None


def get_guardrails() -> QAModeGuardrails:
    """
    Get global guardrails instance.
    
    Returns:
        QAModeGuardrails instance
    """
    global _guardrails_instance
    if _guardrails_instance is None:
        _guardrails_instance = QAModeGuardrails()
    return _guardrails_instance
