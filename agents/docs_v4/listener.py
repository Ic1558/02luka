from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List


def read_jsonl(path: Path, limit: int = 200) -> List[Dict[str, Any]]:
    """
    Read up to `limit` JSONL records from the tail of the file.
    """
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    records: List[Dict[str, Any]] = []
    for line in lines[-limit:]:
        try:
            parsed = json.loads(line)
            if isinstance(parsed, dict):
                records.append(parsed)
        except json.JSONDecodeError:
            continue
    return records


def collect_events(base_dir: Path, telemetry_path: str | None = None, conversations_path: str | None = None, limit: int = 200) -> Dict[str, List[Dict[str, Any]]]:
    telemetry_file = Path(telemetry_path or base_dir / "g/telemetry/lac/events.jsonl")
    conversations_file = Path(conversations_path or base_dir / "g/telemetry/agent_conversations.jsonl")

    return {
        "events": read_jsonl(telemetry_file, limit=limit),
        "conversations": read_jsonl(conversations_file, limit=limit),
    }


__all__ = ["read_jsonl", "collect_events"]
