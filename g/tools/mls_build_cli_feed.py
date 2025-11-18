#!/usr/bin/env python3
"""
Generate a filtered MLS feed for Gemini CLI.

Reads the canonical ledger at g/knowledge/mls_lessons.jsonl, filters the
entries for actionable execution/pattern lessons, and produces a
read-only JSONL feed optimized for the Gemini CLI prompt.
"""

from __future__ import annotations

import argparse
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

BASE = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = BASE / "knowledge" / "mls_lessons.jsonl"
DEFAULT_DEST = BASE / "knowledge" / "mls_lessons_cli.jsonl"
DEFAULT_LIMIT = 50

PREFERRED_KEYWORDS = {
    "gemini",
    "cli",
    "workers",
    "patch",
    "launchagent",
    "launchagents",
    "launchctl",
    "bridge",
    "handler",
    "handlers",
    "watcher",
    "watchers",
    "redis",
    "filesystem",
    "validate",
    "lpe",
    "monitor",
    "path",
}

AREA_KEYWORDS = {
    "launchagents": {"launchagent", "launchagents", "launchctl"},
    "workers": {"worker", "workers", "lpe"},
    "bridge": {"bridge", "handler", "handlers"},
    "watchers": {"watcher", "watchers", "monitor", "monitoring"},
    "patching": {"patch", "patching", "apply", "validate"},
    "cli": {"cli", "gemini", "luka"},
}

ALLOWED_TYPES = {"pattern", "solution"}
SEVERITY_MAP = {
    "pattern": "medium",
    "solution": "medium",
    "failure": "high",
    "improvement": "low",
}


def iter_raw_lessons(path: Path) -> Iterable[dict]:
    """Yield raw JSON objects from the canonical MLS ledger."""
    if not path.exists():
        return

    text = path.read_text(encoding="utf-8")
    decoder = json.JSONDecoder()
    idx = 0
    length = len(text)
    while idx < length:
        while idx < length and text[idx].isspace():
            idx += 1
        if idx >= length:
            break
        try:
            obj, idx = decoder.raw_decode(text, idx)
        except json.JSONDecodeError:
            break
        yield obj


def _parse_timestamp(value: str | None) -> datetime:
    if not value:
        return datetime.fromtimestamp(0, tz=timezone.utc)

    def neutralize(dt: datetime) -> datetime:
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt

    try:
        return neutralize(datetime.fromisoformat(value))
    except ValueError:
        if value.endswith("Z") and "+" not in value:
            try:
                return neutralize(datetime.fromisoformat(value.replace("Z", "+00:00")))
            except ValueError:
                pass

    return datetime.fromtimestamp(0, tz=timezone.utc)


def _matches_keywords(entry: dict) -> bool:
    text = " ".join(
        str(entry.get(field, "")).lower()
        for field in ("title", "description", "context")
    )
    return any(keyword in text for keyword in PREFERRED_KEYWORDS)


def _detect_area(entry: dict) -> str:
    text = " ".join(
        str(entry.get(field, "")).lower()
        for field in ("title", "description", "context")
    )
    for area, keywords in AREA_KEYWORDS.items():
        if keywords & set(text.split()):
            return area
    for area, keywords in AREA_KEYWORDS.items():
        if any(keyword in text for keyword in keywords):
            return area
    return "cli"


def _build_entry(raw: dict) -> dict | None:
    if raw.get("type") not in ALLOWED_TYPES:
        return None
    if not _matches_keywords(raw):
        return None

    updated_at = _parse_timestamp(raw.get("timestamp"))
    pattern = str(raw.get("title") or raw.get("description") or "").strip()
    if "\n" in pattern:
        pattern = pattern.splitlines()[0]

    example = str(raw.get("context") or raw.get("description") or "").strip()
    if "\n" in example:
        example = example.splitlines()[0]

    return {
        "id": raw.get("id", "unknown"),
        "area": _detect_area(raw),
        "severity": SEVERITY_MAP.get(raw.get("type"), "medium"),
        "pattern": pattern,
        "example": example,
        "source": "CLC",
        "updated_at": updated_at.isoformat(),
        "__ts": updated_at,
    }


def build_filtered_feed(source: Path, limit: int) -> list[dict]:
    lessons = [
        entry
        for raw in iter_raw_lessons(source)
        if (entry := _build_entry(raw)) is not None
    ]
    lessons.sort(key=lambda entry: entry["__ts"], reverse=True)
    for entry in lessons:
        entry.pop("__ts", None)
    return lessons[:limit]


def write_feed(dest: Path, lessons: list[dict]) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(
        prefix=f"{dest.name}.tmp.", dir=str(dest.parent)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp_handle:
            for lesson in lessons:
                tmp_handle.write(json.dumps(lesson, ensure_ascii=False))
                tmp_handle.write("\n")
        os.replace(tmp_path, str(dest))
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build the Gemini CLI filtered MLS feed."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help="Canonical MLS ledger path.",
    )
    parser.add_argument(
        "--dest",
        type=Path,
        default=DEFAULT_DEST,
        help="Output CLI-friendly JSONL feed.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=DEFAULT_LIMIT,
        help="Maximum number of lessons to keep.",
    )

    args = parser.parse_args()
    lessons = build_filtered_feed(args.source, args.limit)
    write_feed(args.dest, lessons)
    print(f"Generated {len(lessons)} CLI lessons → {args.dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
