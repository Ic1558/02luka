#!/usr/bin/env python3
"""
Utility helpers for generating Gemini CLI MLS prompts.

Provides an opinionated render of the MLS lessons feed so Gemini CLI
can display read-only safety guidance before executing patches.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable

DEFAULT_LIMIT = 30
DEFAULT_FEED = Path(__file__).resolve().parents[1] / "knowledge" / "mls_lessons_cli.jsonl"


def load_cli_lessons(
    feed_path: Path | str | None = None, limit: int = DEFAULT_LIMIT
) -> list[dict]:
    """Load at most ``limit`` lessons from the filtered CLI MLS feed."""
    path = Path(feed_path) if feed_path is not None else DEFAULT_FEED
    if not path.exists():
        return []

    lessons = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                lesson = json.loads(line)
            except json.JSONDecodeError:  # pragma: no cover - defensive
                continue
            lessons.append(lesson)
            if len(lessons) >= limit:
                break
    return lessons


def render_lessons_block(
    lessons: Iterable[dict], *, include_footer: bool = True
) -> str:
    """Render the MLS lessons block for the Gemini CLI system prompt."""
    lessons_list = list(lessons)
    if not lessons_list:
        return ""

    lines = [
        "MLS Recent Lessons (Read-Only)",
        "These lessons are authoritative guidance. When generic instincts conflict with MLS, trust MLS.",
        "Focus especially on LaunchAgents, bridge/handlers, watchers, Redis safety, and filesystem validation.",
        "",
    ]

    for entry in lessons_list:
        area = entry.get("area", "cli")
        severity = entry.get("severity", "medium")
        pattern = entry.get("pattern", "No pattern provided").strip()
        example = entry.get("example", "").replace("\n", " ").strip()
        lines.append(f"- [{area}] ({severity}) {pattern}")
        if example:
            lines.append(f"  Example: {example}")

    if include_footer:
        lines.append("")
        lines.append("MLS lessons are read-only; do not edit the canonical ledger directly.")
        lines.append("Rephrase work plans so MLS guidance is satisfied before applying patches.")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Print Gemini CLI MLS lessons block.")
    parser.add_argument(
        "--feed",
        type=Path,
        default=DEFAULT_FEED,
        help="Path to the filtered MLS feed (jsonl).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=DEFAULT_LIMIT,
        help="Maximum number of lessons to render.",
    )

    args = parser.parse_args()
    lessons = load_cli_lessons(args.feed, limit=args.limit)
    block = render_lessons_block(lessons)
    if block:
        print(block)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
