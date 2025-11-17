#!/usr/bin/env python3
"""Append Local Patch Engine events into the MLS ledger.

This helper keeps ledger writes consistent so other tooling can
consume daily JSONL files. It intentionally avoids external
dependencies beyond PyYAML (already required by the Luka CLI).
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover - runtime only
    yaml = None


def _load_patch_meta(path: Optional[Path]) -> Dict[str, Any]:
    if not path or not path.exists() or not yaml:
        return {}
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception:
        return {}
    meta = data.get("meta", {}) if isinstance(data, dict) else {}
    return meta if isinstance(meta, dict) else {}


def _as_list(raw: Optional[str]) -> List[str]:
    if not raw:
        return []
    raw = raw.strip()
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            return [str(x) for x in parsed]
    except Exception:
        pass
    return [part.strip() for part in raw.split(",") if part.strip()]


def append_event(
    ledger_dir: Path,
    wo_id: str,
    status: str,
    files: List[str],
    errors: List[str],
    patch_meta: Dict[str, Any],
    source: str = "lpe_worker",
) -> str:
    ledger_dir.mkdir(parents=True, exist_ok=True)
    now = dt.datetime.now(dt.timezone.utc)
    ts = now.isoformat().replace("+00:00", "Z")
    day = now.strftime("%Y-%m-%d")
    event_id = f"MLS-LPE-{now.strftime('%Y%m%d%H%M%S')}"
    entry = {
        "id": event_id,
        "ts": ts,
        "source": source,
        "wo_id": wo_id,
        "status": status,
        "files": files,
        "errors": errors,
        "patch_meta": patch_meta,
    }
    ledger_path = ledger_dir / f"{day}.jsonl"
    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    with ledger_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
    return event_id


def main() -> None:
    parser = argparse.ArgumentParser(description="Append an event to the MLS ledger")
    parser.add_argument("--wo-id", required=True, help="Work order identifier")
    parser.add_argument("--status", required=True, help="status value (success/error/partial/invalid)")
    parser.add_argument("--files", help="Comma-separated or JSON array of touched files", default="")
    parser.add_argument("--errors", help="Comma-separated or JSON array of errors", default="")
    parser.add_argument("--patch-file", help="Optional patch file to extract meta", default=None)
    parser.add_argument("--ledger-dir", help="Override ledger directory")
    args = parser.parse_args()

    base = Path(os.getenv("LUKA_SOT", Path.home() / "02luka"))
    ledger_dir = Path(args.ledger_dir) if args.ledger_dir else base / "mls" / "ledger"
    patch_path = Path(args.patch_file).resolve() if args.patch_file else None

    files = _as_list(args.files)
    errors = _as_list(args.errors)
    patch_meta = _load_patch_meta(patch_path)

    event_id = append_event(ledger_dir, args.wo_id, args.status, files, errors, patch_meta)
    print(event_id)


if __name__ == "__main__":
    main()
