#!/usr/bin/env python3
"""Regenerate R&D memory artifacts for planning nodes.

Outputs:
- g/memory/latest_lessons.json
- g/memory/latest_rules.json
- g/memory/latest_improvement_tickets.json

Each artifact summarizes the most recent markdown files in the corresponding
`g/memory/` subfolder so Architect/Senior nodes can ingest fresh context.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import List

REPO_ROOT = Path(__file__).resolve().parent.parent
MEMORY_ROOT = REPO_ROOT / "g" / "memory"


@dataclass
class MemoryEntry:
    title: str
    path: str
    summary: str
    updated_at: str

    @classmethod
    def from_markdown(cls, path: Path) -> "MemoryEntry":
        title, summary = _parse_markdown(path)
        updated_at = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc).isoformat()
        return cls(title=title, path=str(path.relative_to(REPO_ROOT)), summary=summary, updated_at=updated_at)


def _parse_markdown(path: Path) -> tuple[str, str]:
    title = path.stem.replace("_", " ").title()
    summary = ""

    with path.open(encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped:
                continue
            if stripped.startswith("#"):
                title = stripped.lstrip("# ")
                continue
            summary = stripped
            break

    if not summary:
        summary = "(no summary provided)"

    return title, summary


def collect_entries(folder: Path) -> List[MemoryEntry]:
    markdown_files = sorted(folder.glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True)
    return [MemoryEntry.from_markdown(path) for path in markdown_files]


def write_json(target: Path, entries: List[MemoryEntry]) -> None:
    payload = {
        "generated_at": datetime.now(tz=timezone.utc).isoformat(),
        "entries": [entry.__dict__ for entry in entries],
    }
    target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    lessons = collect_entries(MEMORY_ROOT / "lessons")
    rules = collect_entries(MEMORY_ROOT / "rules")
    tickets = collect_entries(MEMORY_ROOT / "improvement_tickets")

    write_json(MEMORY_ROOT / "latest_lessons.json", lessons)
    write_json(MEMORY_ROOT / "latest_rules.json", rules)
    write_json(MEMORY_ROOT / "latest_improvement_tickets.json", tickets)

    print("Updated R&D memory artifacts:")
    for target in ("latest_lessons.json", "latest_rules.json", "latest_improvement_tickets.json"):
        print(f"- {target}")


if __name__ == "__main__":
    main()
