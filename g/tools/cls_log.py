#!/usr/bin/env python3
"""CLS audit logging helper."""
from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict


DEFAULT_AUDIT_PATH = Path("/Users/icmini/02luka/g/telemetry/cls_audit.jsonl")
CATEGORIES = [
    "work_order",
    "guard",
    "config",
    "secret_cleanup",
    "mode",
    "review",
    "maintenance",
    "incident",
]
STATUSES = ["running", "completed", "failed", "partial", "skipped"]
SEVERITIES = ["info", "warning", "error", "critical"]


def utc_now() -> str:
    """Return current UTC time in ISO8601 format without microseconds and with Z suffix."""
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def load_details(path: Path, parser: argparse.ArgumentParser) -> Dict[str, Any]:
    if not path.exists():
        parser.error(f"Details file does not exist: {path}")
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except Exception as exc:  # noqa: BLE001 - surface parsing issues to the caller
        parser.error(f"Failed to read details file {path}: {exc}")
    if not isinstance(data, dict):
        parser.error("Details file must contain a JSON object")
    return data


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="CLS audit log emitter")
    parser.add_argument("--action", required=True, help="Action name for the event")
    parser.add_argument(
        "--category", required=True, choices=CATEGORIES, help="Category of the event"
    )
    parser.add_argument(
        "--status", required=True, choices=STATUSES, help="Status of the action"
    )
    parser.add_argument(
        "--severity", default="info", choices=SEVERITIES, help="Event severity"
    )
    parser.add_argument(
        "--source",
        default="cls_script",
        help='Source of the event (e.g. "cls_script", "cursor_ide")',
    )
    parser.add_argument("--message", required=True, help="Human-readable summary")
    parser.add_argument(
        "--details-file",
        type=Path,
        help="Path to JSON file containing event details (object)",
    )
    return parser


def emit_event(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    details: Dict[str, Any] | None = None
    if args.details_file:
        details = load_details(args.details_file, parser)

    audit_path = Path(os.environ.get("CLS_AUDIT_PATH", DEFAULT_AUDIT_PATH))
    audit_path.parent.mkdir(parents=True, exist_ok=True)

    event: Dict[str, Any] = {
        "schema_version": "1.0",
        "timestamp": utc_now(),
        "agent": "CLS",
        "action": args.action,
        "category": args.category,
        "status": args.status,
        "severity": args.severity,
        "source": args.source,
        "message": args.message,
    }

    if details is not None:
        event["details"] = details

    with audit_path.open("a", encoding="utf-8") as handle:
        json.dump(event, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    emit_event(args, parser)


if __name__ == "__main__":
    main()
