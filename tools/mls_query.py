#!/usr/bin/env python3
"""
MLS query helper for agents.

Reads g/knowledge/mls_lessons.jsonl (pretty-printed JSON objects separated
by newlines, same format used by /api/mls) and exposes a small CLI:

  python3 tools/mls_query.py summary
  python3 tools/mls_query.py recent --limit 20 --type failure --format json
  python3 tools/mls_query.py search --query "codex sandbox" --format table

This is intentionally read-only and has no side effects.
"""

import argparse
import json
import sys
from pathlib import Path
from datetime import datetime


ROOT = Path(__file__).resolve().parents[1]
MLS_FILE = ROOT / "g" / "knowledge" / "mls_lessons.jsonl"


def load_entries():
  """Load MLS entries from the JSONL file, tolerating the pretty-printed format."""
  if not MLS_FILE.exists():
    return []

  content = MLS_FILE.read_text(encoding="utf-8").strip()
  if not content:
    return []

  # Reuse the same split strategy as the dashboard API:
  parts = content.split('}\n{')
  json_objects = []
  for i, part in enumerate(parts):
    if i == 0:
      json_str = part + '}'
    elif i == len(parts) - 1:
      json_str = '{' + part
    else:
      json_str = '{' + part + '}'
    json_objects.append(json_str)

  entries = []
  for raw in json_objects:
    try:
      entry = json.loads(raw)
      # Normalize fields
      entries.append({
        "id": entry.get("id", "MLS-UNKNOWN"),
        "type": entry.get("type", "other"),
        "title": entry.get("title", "Untitled"),
        "description": entry.get("description", ""),
        "context": entry.get("context", ""),
        "timestamp": entry.get("timestamp", ""),
        "related_wo": entry.get("related_wo"),
        "related_session": entry.get("related_session"),
        "tags": entry.get("tags", []),
        "verified": bool(entry.get("verified", False)),
        "usefulness_score": entry.get("usefulness_score", 0),
        "source": entry.get("source", "unknown"),
      })
    except json.JSONDecodeError:
      # Be tolerant: skip bad objects, but do not fail the whole query
      continue

  return entries


def parse_args(argv):
  parser = argparse.ArgumentParser(
    description="Query MLS lessons for agents (read-only)."
  )

  subparsers = parser.add_subparsers(dest="command", required=True)

  # summary
  subparsers.add_parser("summary", help="Show counts by type and verification.")

  # recent
  recent = subparsers.add_parser("recent", help="Show most recent lessons.")
  recent.add_argument("--limit", type=int, default=20)
  recent.add_argument("--type", dest="type_filter", default="", help="Filter by type")
  recent.add_argument("--source", dest="source_filter", default="", help="Filter by source")
  recent.add_argument("--format", choices=["json", "table"], default="json")

  # search
  search = subparsers.add_parser("search", help="Search by substring in title/description/context.")
  search.add_argument("--query", required=True)
  search.add_argument("--limit", type=int, default=50)
  search.add_argument("--format", choices=["json", "table"], default="json")

  return parser.parse_args(argv)


def cmd_summary(entries):
  by_type = {}
  verified = 0
  for e in entries:
    t = e.get("type", "other")
    by_type[t] = by_type.get(t, 0) + 1
    if e.get("verified"):
      verified += 1

  out = {
    "total": len(entries),
    "verified": verified,
    "by_type": by_type,
  }
  json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
  sys.stdout.write("\n")


def _parse_time(value):
  if not value:
    return None
  # try a few common formats but never fail hard
  for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S"):
    try:
      return datetime.strptime(value, fmt)
    except Exception:
      continue
  return None


def _sort_by_time(entries):
  return sorted(entries, key=lambda e: _parse_time(e.get("timestamp")) or datetime.min, reverse=True)


def _print_table(entries):
  # Very small, agent-friendly table (id, type, time, title)
  for e in entries:
    t = e.get("timestamp") or "-"
    line = f"{e.get('id','?')}\t{e.get('type','other')}\t{t}\t{e.get('title','Untitled')}"
    print(line)


def cmd_recent(entries, args):
  entries = _sort_by_time(entries)

  if args.type_filter:
    entries = [e for e in entries if e.get("type") == args.type_filter]
  if args.source_filter:
    entries = [e for e in entries if e.get("source") == args.source_filter]

  entries = entries[: args.limit]

  if args.format == "json":
    json.dump(entries, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
  else:
    _print_table(entries)


def cmd_search(entries, args):
  q = args.query.lower()

  def matches(e):
    haystack = " ".join([
      e.get("title", ""),
      e.get("description", ""),
      e.get("context", ""),
    ]).lower()
    return q in haystack

  result = [e for e in entries if matches(e)]
  result = _sort_by_time(result)[: args.limit]

  if args.format == "json":
    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
  else:
    _print_table(result)


def main(argv=None):
  args = parse_args(argv or sys.argv[1:])

  entries = load_entries()

  if args.command == "summary":
    cmd_summary(entries)
  elif args.command == "recent":
    cmd_recent(entries, args)
  elif args.command == "search":
    cmd_search(entries, args)
  else:
    raise SystemExit(f"Unknown command: {args.command}")


if __name__ == "__main__":
  main()
