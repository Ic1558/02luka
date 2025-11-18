#!/usr/bin/env python3
"""Append an event to the MLS ledger in JSONL format with schema alignment."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
from typing import Any, Dict, Iterable, Optional

ALLOWED_TYPES = {"solution", "failure", "improvement", "pattern", "antipattern"}
ALLOWED_PRODUCERS = {"cls", "codex", "clc", "gemini"}

DEFAULT_SCHEMA: Dict[str, Any] = {
    "id": "",
    "ts": "",
    "type": "solution",
    "title": "",
    "summary": "",
    "memo": "",
    "source": {
        "producer": "",
        "context": "",
        "session": "",
        "repo": "",
        "run_id": "",
        "workflow": "",
        "sha": "",
        "artifact": "",
        "artifact_path": "",
    },
    "links": {"followup_id": "", "wo_id": ""},
    "tags": [],
    "author": "",
    "confidence": 0.0,
}

OPTIONAL_KEYS = {"schema_version", "meta", "meta_raw"}


def load_json_line(path: pathlib.Path) -> Optional[Dict[str, Any]]:
    if not path.exists():
        return None
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            return json.loads(line)
        except json.JSONDecodeError:
            continue
    return None


def find_baseline_entry(base: pathlib.Path) -> Optional[Dict[str, Any]]:
    ledger_dir = base / "mls" / "ledger"
    if ledger_dir.exists():
        for ledger_file in sorted(ledger_dir.glob("*.jsonl"), reverse=True):
            entry = load_json_line(ledger_file)
            if entry:
                return entry
    lessons = base / "g" / "knowledge" / "mls_lessons.jsonl"
    return load_json_line(lessons)


def merge_schema(template: Dict[str, Any], baseline: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    merged = json.loads(json.dumps(template))  # deep copy
    if not baseline:
        return merged
    for key, value in baseline.items():
        if isinstance(value, dict):
            merged.setdefault(key, {})
            for nested_key in value:
                merged[key].setdefault(nested_key, "")
        elif isinstance(value, list):
            merged.setdefault(key, [])
        else:
            merged.setdefault(key, "" if isinstance(value, str) else value)
    return merged


def fill_missing_from_template(entry: Dict[str, Any], template: Dict[str, Any]) -> None:
    for key, sample in template.items():
        if key not in entry:
            if isinstance(sample, dict):
                entry[key] = {nested: "" for nested in sample}
            elif isinstance(sample, list):
                entry[key] = []
            elif isinstance(sample, str):
                entry[key] = ""
            else:
                entry[key] = sample
        elif isinstance(sample, dict):
            for nested_key, nested_sample in sample.items():
                if not isinstance(entry[key], dict):
                    entry[key] = {nested_key: nested_sample}
                entry[key].setdefault(nested_key, nested_sample if not isinstance(nested_sample, str) else "")


def validate_entry(entry: Dict[str, Any], template: Dict[str, Any]) -> None:
    required_keys = set(DEFAULT_SCHEMA)
    missing_required = [key for key in required_keys if key not in entry or entry.get(key) in (None, "")]
    if missing_required:
        raise ValueError(f"missing required fields: {', '.join(missing_required)}")

    extra_keys = set(entry) - set(template) - OPTIONAL_KEYS
    if extra_keys:
        raise ValueError(f"unexpected fields in entry: {', '.join(sorted(extra_keys))}")

    for key in ("ts", "type", "title", "summary", "author"):
        if not isinstance(entry.get(key), str) or not entry.get(key):
            raise ValueError(f"{key} must be a non-empty string")

    if entry["type"] not in ALLOWED_TYPES:
        raise ValueError(f"invalid type '{entry['type']}' (allowed: {', '.join(sorted(ALLOWED_TYPES))})")

    source = entry.get("source", {})
    if not isinstance(source, dict):
        raise ValueError("source must be an object")
    for required in ("producer", "context"):
        if not isinstance(source.get(required), str):
            raise ValueError(f"source.{required} must be a string")
    if source.get("producer") not in ALLOWED_PRODUCERS:
        raise ValueError(f"source.producer must be one of {', '.join(sorted(ALLOWED_PRODUCERS))}")

    links = entry.get("links", {})
    if not isinstance(links, dict):
        raise ValueError("links must be an object")
    if not isinstance(links.get("wo_id"), str):
        raise ValueError("links.wo_id must be a string")

    tags = entry.get("tags")
    if not isinstance(tags, list) or any(not isinstance(tag, str) for tag in tags):
        raise ValueError("tags must be a list of strings")

    confidence = entry.get("confidence")
    if not isinstance(confidence, (int, float)) or not (0 <= float(confidence) <= 1):
        raise ValueError("confidence must be a number between 0 and 1")


def parse_tags(tag_args: Iterable[str]) -> list[str]:
    tags = []
    for tag in tag_args:
        tags.extend([part.strip() for part in tag.split(",") if part.strip()])
    return tags


def build_ledger_entry(args: argparse.Namespace, base: pathlib.Path, template: Dict[str, Any]) -> Dict[str, Any]:
    timestamp = args.timestamp or dt.datetime.utcnow().isoformat() + "Z"
    ledger_id = f"MLS-{dt.datetime.utcnow():%Y%m%d-%H%M%S}"

    derived_type = args.event_type or ("failure" if args.status and args.status.lower() not in {"success", "dry_run"} else "solution")
    if derived_type not in ALLOWED_TYPES:
        derived_type = "failure"

    producer = (args.producer or args.source or "codex").lower()
    if producer not in ALLOWED_PRODUCERS:
        producer = "codex"

    tags = parse_tags(args.tags)
    if args.status:
        tags.append(f"status:{args.status}")
    if args.source:
        tags.append(f"source:{args.source}")

    summary = args.summary or args.message or f"LPE patch {args.status or 'update'}"
    memo = args.memo or (args.patch_file or "")
    title = args.title or f"LPE {derived_type} ({args.wo_id})"

    entry: Dict[str, Any] = {
        "id": ledger_id,
        "ts": timestamp,
        "type": derived_type,
        "title": title,
        "summary": summary,
        "memo": memo,
        "source": {
            "producer": producer,
            "context": args.context or args.source or "lpe_worker",
            "session": args.session or "",
            "repo": args.repo or "",
            "run_id": args.run_id or "",
            "workflow": args.workflow or "",
            "sha": args.sha or "",
            "artifact": args.artifact or "",
            "artifact_path": args.artifact_path or "",
        },
        "links": {
            "followup_id": args.followup_id or "",
            "wo_id": args.wo_id,
        },
        "tags": tags,
        "author": args.author or producer,
        "confidence": args.confidence,
    }

    if args.schema_version:
        entry["schema_version"] = args.schema_version

    if args.metadata:
        try:
            entry["meta"] = json.loads(args.metadata)
        except json.JSONDecodeError:
            entry["meta_raw"] = args.metadata

    fill_missing_from_template(entry, template)
    validate_entry(entry, template)
    return entry


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wo-id", required=True, help="Work order identifier")
    parser.add_argument("--status", required=True, help="Status label for the patch")
    parser.add_argument("--patch-file", help="Path to patch file used by LPE")
    parser.add_argument("--message", default="", help="Human readable context")
    parser.add_argument("--source", default="lpe", help="Event producer context")
    parser.add_argument("--metadata", help="Optional JSON metadata string")
    parser.add_argument("--timestamp", help="Override timestamp")
    parser.add_argument("--ledger-dir", default=None, help="Ledger directory (defaults to <repo>/mls/ledger)")
    parser.add_argument("--event-type", dest="event_type", help="Override event type")
    parser.add_argument("--title", help="Ledger title override")
    parser.add_argument("--summary", help="Ledger summary override")
    parser.add_argument("--memo", help="Optional memo field")
    parser.add_argument("--author", default="codex", help="Author of the entry")
    parser.add_argument("--producer", help="Producer name (codex/cls/clc/gemini)")
    parser.add_argument("--context", help="Context string for source")
    parser.add_argument("--session", help="Session identifier")
    parser.add_argument("--repo", help="Repository name")
    parser.add_argument("--run-id", dest="run_id", help="Run identifier")
    parser.add_argument("--workflow", help="Workflow identifier")
    parser.add_argument("--sha", help="Commit SHA")
    parser.add_argument("--artifact", help="Artifact name")
    parser.add_argument("--artifact-path", dest="artifact_path", help="Path to artifact")
    parser.add_argument("--followup-id", dest="followup_id", help="Followup identifier")
    parser.add_argument("--schema-version", dest="schema_version", help="Optional schema version")
    parser.add_argument("--tag", dest="tags", action="append", default=[], help="Tag (repeatable, comma-separated supported)")
    parser.add_argument("--confidence", type=float, default=0.9, help="Confidence score between 0 and 1")

    args = parser.parse_args()

    repo_root = pathlib.Path(__file__).resolve().parents[2]
    ledger_dir = pathlib.Path(args.ledger_dir) if args.ledger_dir else repo_root / "mls" / "ledger"
    ledger_dir.mkdir(parents=True, exist_ok=True)

    baseline = find_baseline_entry(repo_root)
    template = merge_schema(DEFAULT_SCHEMA, baseline)

    event = build_ledger_entry(args, repo_root, template)
    ledger_path = ledger_dir / f"{dt.date.today():%Y-%m-%d}.jsonl"
    with ledger_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, ensure_ascii=False) + "\n")

    print(event.get("id", ""))


if __name__ == "__main__":
    main()
