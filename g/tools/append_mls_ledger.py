#!/usr/bin/env python3
"""Append an event to the MLS ledger in JSONL format."""

import argparse
import datetime as dt
import json
import pathlib
from typing import Any, Dict, Optional


STATUS_TYPE_MAP = {
    "success": "solution",
    "error": "failure",
    "failure": "failure",
    "invalid": "failure",
}


def _relative_patch_path(patch_file: Optional[str], base: pathlib.Path) -> Optional[str]:
    if not patch_file:
        return None
    patch_path = pathlib.Path(patch_file).expanduser().resolve()
    try:
        patch_path = patch_path.relative_to(base)
    except ValueError:
        pass
    return str(patch_path)


def build_event(args: argparse.Namespace, base: pathlib.Path) -> Dict[str, Any]:
    now = dt.datetime.now(dt.timezone.utc)
    timestamp = args.timestamp or now.isoformat()
    ledger_id = f"MLS-LPE-{now:%Y%m%d-%H%M%S}"
    status_key = (args.status or "").strip().lower()
    event_type = STATUS_TYPE_MAP.get(status_key, "observation")

    patch_path = _relative_patch_path(args.patch_file, base)
    summary = args.message or f"LPE reported status '{args.status}' for {args.wo_id}"

    event: Dict[str, Any] = {
        "id": ledger_id,
        "ts": timestamp,
        "type": event_type,
        "title": f"LPE {status_key or 'status'} – {args.wo_id}",
        "summary": summary,
        "source": {
            "producer": args.source or "lpe_worker",
            "context": "lpe",
            "wo_id": args.wo_id,
        },
        "links": {
            "followup_id": "",
            "wo_id": args.wo_id,
            "patch_file": patch_path,
        },
        "tags": [
            "lpe",
            f"status:{status_key or 'unknown'}",
        ],
        "author": args.source or "lpe_worker",
        "confidence": 0.8 if status_key == "success" else 0.4,
    }

    if args.metadata:
        memo_value: str
        try:
            parsed = json.loads(args.metadata)
            if isinstance(parsed, (dict, list)):
                memo_value = json.dumps(parsed, ensure_ascii=False)
            else:
                memo_value = str(parsed)
        except json.JSONDecodeError:
            memo_value = args.metadata
        event["memo"] = memo_value

    return event, ledger_id


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wo-id", required=True, help="Work order identifier")
    parser.add_argument("--status", required=True, help="Status label for the patch")
    parser.add_argument("--patch-file", help="Path to patch file used by LPE")
    parser.add_argument("--message", default="", help="Human readable context")
    parser.add_argument("--source", default="lpe", help="Event producer")
    parser.add_argument("--metadata", help="Optional JSON metadata string")
    parser.add_argument("--timestamp", help="Override timestamp")
    parser.add_argument(
        "--ledger-dir",
        default=None,
        help="Ledger directory (defaults to <repo>/mls/ledger)",
    )

    args = parser.parse_args()

    repo_root = pathlib.Path(__file__).resolve().parents[2]
    ledger_dir = pathlib.Path(args.ledger_dir) if args.ledger_dir else repo_root / "mls" / "ledger"
    ledger_dir.mkdir(parents=True, exist_ok=True)

    event, ledger_id = build_event(args, repo_root)
    ledger_path = ledger_dir / f"{dt.date.today():%Y-%m-%d}.jsonl"
    with ledger_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, ensure_ascii=False) + "\n")

    print(ledger_id)


if __name__ == "__main__":
    main()
