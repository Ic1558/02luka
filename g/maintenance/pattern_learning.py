from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Dict, List

from agents.rnd.rnd_agent import RnDAgent


def run(failures: List[Dict[str, object]] | None = None) -> Dict[str, object]:
    base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
    failures = failures or _read_qa_failures(base_dir)
    agent = RnDAgent(pattern_db_path=base_dir / "agents/rnd/pattern_db.yaml")
    result = agent.run(failures)
    _write_rnd_telemetry(base_dir, result, failures)
    return result


def _read_qa_failures(base_dir: Path) -> List[Dict[str, object]]:
    path = base_dir / "g/telemetry/qa_checklists.jsonl"
    if not path.exists():
        return []
    failures: List[Dict[str, object]] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return []
    for line in lines:
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        checklist = rec.get("checklist", {})
        if checklist.get("status") == "fail":
            failures.append({"reason": "CHECKLIST_FAILED", "raw": rec})
        basic = rec.get("basic_checks", {})
        if basic.get("status") != "success":
            failures.append({"reason": basic.get("reason", "BASIC_CHECKS_FAILED"), "raw": rec})
    return failures


def _write_rnd_telemetry(base_dir: Path, result: Dict[str, object], failures: List[Dict[str, object]]) -> None:
    path = base_dir / "g/telemetry/rnd_analysis.jsonl"
    record = {
        "failures_seen": len(failures),
        "result": result,
    }
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record) + "\n")
    except Exception:
        return


__all__ = ["run"]
