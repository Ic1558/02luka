#!/usr/bin/env python3
"""Lightweight Paula ingest stub for development and testing."""
from __future__ import annotations

import argparse
import base64
import json
import os
import sys
from typing import Any, Dict


def decode_payload(encoded: str) -> Dict[str, Any]:
    if not encoded:
        return {}
    try:
        decoded = base64.b64decode(encoded).decode("utf-8")
        return json.loads(decoded)
    except Exception as exc:  # pragma: no cover - defensive logging only
        print(f"[error] Unable to decode payload: {exc}", file=sys.stderr)
        return {}


def main() -> int:
    parser = argparse.ArgumentParser(description="Paula ingest worker")
    parser.add_argument("--payload-base64", dest="payload_base64", default="", help="Base64 encoded JSON payload")
    args = parser.parse_args()

    payload = decode_payload(args.payload_base64)
    run_id = os.environ.get("PAULA_RUN_ID", "unknown")

    print(f"[info] Ingest job {run_id} received payload with keys: {sorted(payload.keys())}")
    print("[info] Performing ingest steps...")
    # Placeholder work: iterate deterministic order for stable logs.
    for key in sorted(payload.keys()):
        print(f"[debug] processing field: {key} -> {payload[key]!r}")

    print("[info] Ingest complete.")
    return 0


if __name__ == "__main__":  # pragma: no cover - script entrypoint
    sys.exit(main())
