#!/usr/bin/env python3
"""Skill: ui_emit - return structured acknowledgement for UI demos."""

import json
import sys
import time
from datetime import datetime


def main():
    start = time.time()
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(json.dumps({"ok": False, "error": f"invalid JSON input: {exc}"}))
        return

    params = payload.get("params", {})
    response = {
        "title": params.get("title", "Automation stub"),
        "notes": params.get("notes", ""),
        "model": params.get("model"),
        "prompt": params.get("prompt"),
        "extra": params.get("extra"),
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

    # Remove empty fields to keep output tidy
    compact = {k: v for k, v in response.items() if v not in (None, "", {})}

    duration = int((time.time() - start) * 1000)
    print(json.dumps({
        "ok": True,
        "ack": compact,
        "duration_ms": duration
    }))


if __name__ == "__main__":
    main()
