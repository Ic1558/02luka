#!/usr/bin/env python3
"""
ATG Memory Loader v0.1 (Liam)

Reads the last N entries from the Liam memory ledger and prints:
{
  "recent_learnings": ["...", "...", ...]
}
"""

import argparse
import json
import os
import sys
from collections import deque
from pathlib import Path
from typing import List, Deque


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

    # Try to locate repo root by walking up until we see 'g' directory
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        g_dir = parent / "g"
        if g_dir.is_dir():
            return parent / "g" / "memory" / "ledger" / "liam_memory.jsonl"

    # Fallback: assume cwd is repo root
    return cwd / "g" / "memory" / "ledger" / "liam_memory.jsonl"


def read_last_lines(path: Path, limit: int) -> Deque[str]:
    """
    Efficiently read the last `limit` lines of a potentially large file.
    Returns a deque of raw lines (without trailing newlines).
    """
    lines: Deque[str] = deque(maxlen=limit)
    try:
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if line:
                    lines.append(line)
    except FileNotFoundError:
        # No memory yet → return empty
        return deque()
    return lines


def extract_learnings(lines: Deque[str]) -> List[str]:
    """
    Parse JSONL lines and extract the 'learning' field when present.
    """
    learnings: List[str] = []
    for raw in lines:
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue
        learning = obj.get("learning")
        if isinstance(learning, str) and learning.strip():
            learnings.append(learning.strip())
    return learnings


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Load recent Liam learnings for ATG."
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=5,
        help="Number of recent learnings to return (default: 5)",
    )
    args = parser.parse_args(argv)

    ledger_path = get_ledger_path()
    lines = read_last_lines(ledger_path, args.limit)
    learnings = extract_learnings(lines)

    payload = {"recent_learnings": learnings}
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
