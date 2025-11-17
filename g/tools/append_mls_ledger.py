#!/usr/bin/env python3
"""Append an event to the MLS ledger in JSONL format."""

import argparse
import datetime as dt
import json
import pathlib
from typing import Any, Dict


def build_event(args: argparse.Namespace, base: pathlib.Path) -> Dict[str, Any]:
    timestamp = args.timestamp or dt.datetime.utcnow().isoformat() + "Z"
    ledger_id = f"MLS-LPE-{dt.datetime.utcnow():%Y%m%d-%H%M%S}"

    patch_path = None
    if args.patch_file:
        patch_path = pathlib.Path(args.patch_file).expanduser().resolve()
        try:
            patch_path = patch_path.relative_to(base)
        except ValueError:
            pass
        patch_path = str(patch_path)

    event: Dict[str, Any] = {
        "id": ledger_id,
        "ts": timestamp,
        "source": args.source,
        "wo_id": args.wo_id,
        "status": args.status,
        "patch_file": patch_path,
        "message": args.message,
    }

    if args.metadata:
        try:
            event["meta"] = json.loads(args.metadata)
        except json.JSONDecodeError:
            event["meta_raw"] = args.metadata

    return event


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

    event = build_event(args, repo_root)
    ledger_path = ledger_dir / f"{dt.date.today():%Y-%m-%d}.jsonl"
    with ledger_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, ensure_ascii=False) + "\n")

    print(event["id"])


if __name__ == "__main__":
    main()
