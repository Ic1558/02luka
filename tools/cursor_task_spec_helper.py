#!/usr/bin/env python3
# 02luka V4 - Cursor Task Spec Helper
from __future__ import annotations

import json
import sys
from typing import Any, Dict, List


def make_task_spec(
    source: str,
    intent: str,
    target_files: List[str],
    description: str,
    constraints: List[str] | None = None,
    output_format: str = "unified_patch",
) -> Dict[str, Any]:
    return {
        "task_spec": {
            "id": None,
            "source": source,
            "intent": intent,
            "target_files": target_files,
            "command": None,
            "ui_action": None,
            "context": {
                "description": description,
                "background": None,
                "constraints": constraints or [],
                "links": [],
            },
            "output": {
                "format": output_format,
                "apply_mode": "overseer-approved",
            },
        }
    }


def main() -> None:
    if len(sys.argv) < 4:
        print("usage: cursor_task_spec_helper.py SOURCE INTENT DESCRIPTION FILE1 [FILE2 ...]", file=sys.stderr)
        raise SystemExit(1)

    source = sys.argv[1]
    intent = sys.argv[2]
    description = sys.argv[3]
    files = sys.argv[4:]

    spec = make_task_spec(source, intent, files, description)
    print(json.dumps(spec, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
