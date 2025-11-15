#!/usr/bin/env zsh
# CLS Session Summary Generator
# Usage: cls_session_summary.zsh <session_id> [output_file]
# Generates a markdown summary of a CLS session from ledger entries

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
SESSION_ID="${1:-}"
OUTPUT_FILE="${2:-}"

if [[ -z "$SESSION_ID" ]]; then
  echo "Usage: cls_session_summary.zsh <session_id> [output_file]" >&2
  exit 1
fi

# Extract date from session_id (YYYY-MM-DD_agent_NNN)
DATE=$(echo "$SESSION_ID" | cut -d'_' -f1)
LEDGER_FILE="$REPO_ROOT/g/ledger/cls/$DATE.jsonl"

if [[ ! -f "$LEDGER_FILE" ]]; then
  echo "Error: Ledger file not found: $LEDGER_FILE" >&2
  exit 1
fi

# Generate summary from ledger entries
SUMMARY=$(python3 <<PY
import json
import sys
from datetime import datetime

session_id = "$SESSION_ID"
ledger_file = "$LEDGER_FILE"

entries = []
with open(ledger_file, 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            if entry.get('session_id') == session_id:
                entries.append(entry)
        except json.JSONDecodeError:
            continue

if not entries:
    print(f"# Session Summary: {session_id}\n\nNo entries found for this session.")
    sys.exit(0)

# Sort by timestamp
entries.sort(key=lambda x: x.get('ts', ''))

# Generate markdown
print(f"# CLS Session Summary: {session_id}\n")
print(f"**Date:** {date}\n")
print(f"**Total Events:** {len(entries)}\n\n")

# Timeline
print("## Timeline\n")
for entry in entries:
    ts = entry.get('ts', '')
    event = entry.get('event', '')
    task_id = entry.get('task_id', '')
    summary = entry.get('summary', '')
    print(f"- **{ts}** [{event}] {summary}")
    if task_id and task_id != 'unknown':
        print(f"  - Task: `{task_id}`")
    print()

# Tasks completed
tasks = [e for e in entries if e.get('event') == 'task_result']
if tasks:
    print("## Tasks Completed\n")
    for entry in tasks:
        task_id = entry.get('task_id', '')
        summary = entry.get('summary', '')
        data = entry.get('data', {})
        status = data.get('status', 'unknown')
        print(f"- **{task_id}**: {summary}")
        print(f"  - Status: {status}")
        if 'duration_sec' in data:
            print(f"  - Duration: {data['duration_sec']}s")
        print()

# Errors
errors = [e for e in entries if e.get('event') == 'error']
if errors:
    print("## Errors\n")
    for entry in errors:
        ts = entry.get('ts', '')
        summary = entry.get('summary', '')
        data = entry.get('data', {})
        error_msg = data.get('error', summary)
        print(f"- **{ts}**: {error_msg}\n")

# Lessons learned (if any)
print("## Notes\n")
print("_Session summary generated from ledger entries._\n")
PY
)

# Write to file or stdout
if [[ -n "$OUTPUT_FILE" ]]; then
  SESSIONS_DIR="$REPO_ROOT/memory/cls/sessions"
  mkdir -p "$SESSIONS_DIR"
  echo "$SUMMARY" > "$OUTPUT_FILE"
  echo "✅ Session summary written: $OUTPUT_FILE"
else
  echo "$SUMMARY"
fi
