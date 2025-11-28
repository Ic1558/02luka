from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional

from agents.rnd.failure_analyzer import analyze_failures
from agents.rnd.pattern_learner import load_patterns, update_patterns


class RnDAgent:
    """
    Minimal R&D agent that reviews failure records and updates pattern DB.
    Intended to run in background tasks, not in the main pipeline path.
    """

    def __init__(self, pattern_db_path: str = "agents/rnd/pattern_db.yaml"):
        self.pattern_db_path = Path(pattern_db_path)

    def run(self, failures: List[Dict[str, Any]]) -> Dict[str, Any]:
        patterns = load_patterns(self.pattern_db_path)
        insights = analyze_failures(failures, patterns)
        updated = update_patterns(self.pattern_db_path, patterns, insights.get("new_patterns", []))
        return {
            "status": "success",
            "insights": insights,
            "patterns_updated": updated,
            "pattern_db": str(self.pattern_db_path),
        }


__all__ = ["RnDAgent"]
