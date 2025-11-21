#!/usr/bin/env python3
"""
ATG Memory Saver v0.1 (Liam)

Appends a single learning to the Liam memory ledger as JSONL:
{
  "timestamp": "...",
  "outcome": "success" | "failure",
  "learning": "..."
}
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


VALID_OUTCOMES = {"success", "failure", "partial"}


def get_ledger_path() -> Path:
    """
    Resolve the ledger path.

    Env override:
      LIAM_MEMORY_LEDGER=/custom/path.jsonl
    Default:
      g/memory/ledger/liam_memory.jsonl (from repo root)
    """
    env_path = os.environ.get("LIAM_MEMORY_LEDGER")
    if env_path:
        return Path(env_path).expanduser().resolve()

    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        g_dir = parent / "g"
        if g_dir.is_dir():
            return parent / "g" / "memory" / "ledger" / "liam_memory.jsonl"

    return cwd / "g" / "memory" / "ledger" / "liam_memory.jsonl"


def ensure_parent_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Save a single Liam learning to the memory ledger."
    )
    parser.add_argument(
        "--outcome",
        required=True,
        choices=sorted(VALID_OUTCOMES),
        help="Outcome classification for this learning.",
    )
    parser.add_argument(
        "--learning",
        required=True,
        help="Single concise sentence describing the key learning.",
    )
    args = parser.parse_args(argv)

    learning_text = args.learning.strip()
    if not learning_text:
        print("ERROR: learning text is empty", file=sys.stderr)
        return 1

    timestamp = datetime.now(timezone.utc).isoformat()

    entry = {
        "timestamp": timestamp,
        "outcome": args.outcome,
        "learning": learning_text,
    }

    ledger_path = get_ledger_path()
    ensure_parent_dir(ledger_path)

    with ledger_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    print(f"✅ Saved learning to {ledger_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
