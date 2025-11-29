from __future__ import annotations

import yaml
from pathlib import Path
from typing import Any, Dict, List


def load_patterns(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {"known_reasons": [], "patterns": []}
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {"known_reasons": [], "patterns": []}
    except Exception:
        return {"known_reasons": [], "patterns": []}


def update_patterns(path: Path, patterns: Dict[str, Any], new_patterns: List[Dict[str, Any]]) -> Dict[str, Any]:
    if not new_patterns:
        return {"status": "skipped", "updated": False}
    patterns = dict(patterns or {})
    known = set(patterns.get("known_reasons", []))
    for p in new_patterns:
        reason = p.get("reason")
        if reason and reason not in known:
            known.add(reason)
    patterns["known_reasons"] = sorted(known)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(yaml.safe_dump(patterns), encoding="utf-8")
        return {"status": "success", "updated": True, "file": str(path)}
    except Exception as exc:
        return {"status": "error", "reason": str(exc), "updated": False}


__all__ = ["load_patterns", "update_patterns"]
