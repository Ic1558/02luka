from __future__ import annotations

from collections import Counter
from typing import Any, Dict, List


def analyze_failures(failures: List[Dict[str, Any]], patterns: Dict[str, Any]) -> Dict[str, Any]:
    """
    Inspect failure records and suggest pattern updates.
    Currently counts reasons and surfaces top offenders.
    """
    reasons = Counter([f.get("reason", "unknown") for f in failures])
    top_reason, count = ("", 0)
    if reasons:
        top_reason, count = reasons.most_common(1)[0]

    suggestions = []
    if top_reason and top_reason not in patterns.get("known_reasons", []):
        suggestions.append({"reason": top_reason, "count": count, "action": "add_to_known_reasons"})

    return {"status": "analyzed", "top_reason": top_reason, "count": count, "suggestions": suggestions, "new_patterns": suggestions}


__all__ = ["analyze_failures"]
