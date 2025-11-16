#!/usr/bin/env zsh
# AP/IO v3.1 Ledger Pretty Print Tool
# Purpose: Pretty print and analyze ledger entries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# tools/ap_io_v31 -> tools -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
READER="$SCRIPT_DIR/reader.zsh"

usage() {
  cat >&2 <<EOF
Usage: $0 <ledger_file> [options]

Options:
  --group-by correlation|parent|agent  Group entries by field
  --filter <field>=<value>             Filter entries (agent, event, correlation, parent)
  --timeline                           Show timeline view
  --summary                            Show summary statistics
  --format json|pretty|table           Output format (default: pretty)

Examples:
  $0 g/ledger/cls/2025-11-16.jsonl
  $0 g/ledger/cls/2025-11-16.jsonl --group-by correlation
  $0 g/ledger/cls/2025-11-16.jsonl --filter agent=cls --filter event=task_result
  $0 g/ledger/cls/2025-11-16.jsonl --timeline
  $0 g/ledger/cls/2025-11-16.jsonl --summary
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

LEDGER_FILE="$1"
shift

GROUP_BY=""
TIMELINE=false
SUMMARY=false
FORMAT="pretty"
FILTERS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --group-by)
      GROUP_BY="$2"
      shift 2
      ;;
    --timeline)
      TIMELINE=true
      shift
      ;;
    --summary)
      SUMMARY=true
      shift
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --filter)
      FILTERS+=("$2")
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Check file exists
if [ ! -f "$LEDGER_FILE" ]; then
  echo "❌ Ledger file not found: $LEDGER_FILE" >&2
  exit 1
fi

# Check jq availability
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required" >&2
  exit 1
fi

# Build reader command with filters
READER_CMD=("$READER" "$LEDGER_FILE" --format json)
for filter in "${FILTERS[@]}"; do
  field="${filter%%=*}"
  value="${filter#*=}"
  case "$field" in
    agent)
      READER_CMD+=(--agent "$value")
      ;;
    event)
      READER_CMD+=(--event "$value")
      ;;
    correlation)
      READER_CMD+=(--correlation "$value")
      ;;
    parent)
      READER_CMD+=(--parent "$value")
      ;;
  esac
done

# Collect entries (reader outputs JSONL - one JSON object per line)
ENTRIES_RAW=$("${READER_CMD[@]}" 2>/dev/null || echo "")

if [ -z "$ENTRIES_RAW" ] || [ -z "$(echo "$ENTRIES_RAW" | tr -d '\n' | tr -d ' ')" ]; then
  echo "No entries found" >&2
  exit 0
fi

# Convert JSONL to JSON array for processing
ENTRIES=$(echo "$ENTRIES_RAW" | jq -s '.')

# Summary statistics
if [ "$SUMMARY" = true ]; then
  echo "=========================================="
  echo "Ledger Summary: $(basename "$LEDGER_FILE")"
  echo "=========================================="
  echo
  
  TOTAL=$(echo "$ENTRIES" | jq 'length')
  echo "Total entries: $TOTAL"
  echo
  
  # By agent
  echo "By Agent:"
  echo "$ENTRIES" | jq -r 'group_by(.agent) | .[] | "  \(.[0].agent): \(length)"'
  echo
  
  # By event type
  echo "By Event Type:"
  echo "$ENTRIES" | jq -r 'group_by(.event.type) | .[] | "  \(.[0].event.type): \(length)"'
  echo
  
  # Success/failure
  SUCCESS=$(echo "$ENTRIES" | jq '[.[] | select(.data.status == "success")] | length')
  FAILURE=$(echo "$ENTRIES" | jq '[.[] | select(.data.status == "failure")] | length')
  echo "Status:"
  echo "  Success: $SUCCESS"
  echo "  Failure: $FAILURE"
  echo
  
  # Average duration
  AVG_DUR=$(echo "$ENTRIES" | jq '[.[] | .data.execution_duration_ms // (.data.duration_sec // 0 * 1000)] | map(select(. > 0)) | if length > 0 then add / length else 0 end')
  if [ "$AVG_DUR" != "null" ] && [ -n "$AVG_DUR" ] && [ "$AVG_DUR" != "0" ]; then
    echo "Average execution duration: ${AVG_DUR}ms"
  fi
  echo
  
  exit 0
fi

# Timeline view
if [ "$TIMELINE" = true ]; then
  echo "=========================================="
  echo "Timeline: $(basename "$LEDGER_FILE")"
  echo "=========================================="
  echo
  
  echo "$ENTRIES" | jq -s -r 'sort_by(.ts) | .[] | 
    "\(.ts) [\(.agent)] \(.event.type) - \(.event.summary // .event.task_id // "N/A")"'
  
  exit 0
fi

# Group by correlation
if [ "$GROUP_BY" = "correlation" ]; then
  echo "=========================================="
  echo "Grouped by Correlation ID"
  echo "=========================================="
  echo
  
  echo "$ENTRIES" | jq -s -r 'group_by(.correlation_id) | .[] | 
    "Correlation: \(.[0].correlation_id // "none")
\(.[] | "  \(.ts) [\(.agent)] \(.event.type) - \(.event.summary // .event.task_id // "N/A")")
"'
  
  exit 0
fi

# Group by parent
if [ "$GROUP_BY" = "parent" ]; then
  echo "=========================================="
  echo "Grouped by Parent ID"
  echo "=========================================="
  echo
  
  echo "$ENTRIES" | jq -s -r 'group_by(.parent_id) | .[] | 
    "Parent: \(.[0].parent_id // "none")
\(.[] | "  \(.ts) [\(.agent)] \(.event.type) - \(.event.summary // .event.task_id // "N/A")")
"'
  
  exit 0
fi

# Group by agent
if [ "$GROUP_BY" = "agent" ]; then
  echo "=========================================="
  echo "Grouped by Agent"
  echo "=========================================="
  echo
  
  echo "$ENTRIES" | jq -s -r 'group_by(.agent) | .[] | 
    "Agent: \(.[0].agent)
\(.[] | "  \(.ts) \(.event.type) - \(.event.summary // .event.task_id // "N/A")")
"'
  
  exit 0
fi

# Default: pretty print
if [ "$FORMAT" = "pretty" ]; then
  echo "$ENTRIES" | jq -r '.[] | 
    "========================================
Ledger ID: \(.ledger_id // "N/A")
Timestamp: \(.ts)
Agent: \(.agent)
Event: \(.event.type)
Task ID: \(.event.task_id // "N/A")
Summary: \(.event.summary // "N/A")
Status: \(.data.status // "N/A")
Duration: \(.data.execution_duration_ms // (.data.duration_sec // 0 * 1000) // "N/A")ms
Correlation: \(.correlation_id // "N/A")
Parent: \(.parent_id // "N/A")
========================================"'
elif [ "$FORMAT" = "table" ]; then
  echo "$ENTRIES" | jq -r '["Timestamp", "Agent", "Event", "Task ID", "Status", "Duration (ms)"], 
    (.[] | [.ts, .agent, .event.type, .event.task_id // "N/A", .data.status // "N/A", .data.execution_duration_ms // (.data.duration_sec // 0 * 1000) // "N/A"]) | 
    @tsv' | column -t
else
  echo "$ENTRIES" | jq '.'
fi

exit 0
