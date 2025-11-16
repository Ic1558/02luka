#!/usr/bin/env zsh
# AP/IO v3.1 Pretty Printer
# Purpose: Pretty print and analyze ledger entries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
# tools/ap_io_v31 -> tools -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
READER="$SCRIPT_DIR/reader.zsh"

usage() {
  cat >&2 <<EOF
Usage: $0 <ledger_file> [mode]

Modes:
  summary     - Show summary statistics (default)
  timeline    - Show timeline view
  group       - Group by agent/event type
  filter      - Apply filters (use with --agent, --event-type, etc.)

Options:
  --agent <agent>           Filter by agent
  --event-type <type>       Filter by event type
  --correlation <id>        Filter by correlation ID
  --format <json|table>     Output format

Examples:
  $0 g/ledger/cls/2025-11-17.jsonl
  $0 g/ledger/cls/2025-11-17.jsonl timeline
  $0 g/ledger/cls/2025-11-17.jsonl group --agent cls
EOF
  exit 1
}

# Parse arguments
LEDGER_FILE=""
MODE="summary"
AGENT_FILTER=""
EVENT_TYPE_FILTER=""
CORRELATION_FILTER=""
OUTPUT_FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      AGENT_FILTER="$2"
      shift 2
      ;;
    --event-type)
      EVENT_TYPE_FILTER="$2"
      shift 2
      ;;
    --correlation)
      CORRELATION_FILTER="$2"
      shift 2
      ;;
    --format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    summary|timeline|group|filter)
      MODE="$1"
      shift
      ;;
    *)
      if [ -z "$LEDGER_FILE" ]; then
        LEDGER_FILE="$1"
      else
        echo "❌ Unknown option: $1" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [ -z "$LEDGER_FILE" ] || [ ! -f "$LEDGER_FILE" ]; then
  echo "❌ Error: Ledger file required" >&2
  usage
fi

# Build reader command
READER_CMD="$READER \"$LEDGER_FILE\""
[ -n "$AGENT_FILTER" ] && READER_CMD="$READER_CMD --agent $AGENT_FILTER"
[ -n "$EVENT_TYPE_FILTER" ] && READER_CMD="$READER_CMD --event-type $EVENT_TYPE_FILTER"
[ -n "$CORRELATION_FILTER" ] && READER_CMD="$READER_CMD --correlation $CORRELATION_FILTER"

# Read entries
ENTRIES=$(eval "$READER_CMD" 2>/dev/null)

if [ -z "$ENTRIES" ]; then
  echo "No entries found"
  exit 0
fi

# Convert to JSON array for processing
JSON_ARRAY=$(echo "$ENTRIES" | jq -s '.' 2>/dev/null || echo "[]")

# Process based on mode
case "$MODE" in
  summary)
    TOTAL=$(echo "$JSON_ARRAY" | jq 'length')
    AGENTS=$(echo "$JSON_ARRAY" | jq -r '[.[].agent] | unique | .[]' | sort -u | wc -l | tr -d ' ')
    EVENTS=$(echo "$JSON_ARRAY" | jq -r '[.[].event.type] | unique | .[]' | sort -u | wc -l | tr -d ' ')
    
    # Calculate average duration (handle nulls)
    AVG_DUR=$(echo "$JSON_ARRAY" | jq '[.[] | select(.execution_duration_ms != null and .execution_duration_ms > 0) | .execution_duration_ms] | if length > 0 then add / length else 0 end')
    
    echo "Summary Statistics"
    echo "=================="
    echo "Total Entries: $TOTAL"
    echo "Unique Agents: $AGENTS"
    echo "Unique Event Types: $EVENTS"
    echo "Average Duration: ${AVG_DUR}ms"
    ;;
    
  timeline)
    echo "$JSON_ARRAY" | jq -r '.[] | "\(.ts) [\(.agent)] \(.event.type): \(.event.summary // "-")"'
    ;;
    
  group)
    echo "$JSON_ARRAY" | jq -r 'group_by(.agent) | .[] | "Agent: \(.[0].agent) (\(length) entries)"'
    ;;
    
  filter)
    if [ "$OUTPUT_FORMAT" = "json" ]; then
      echo "$JSON_ARRAY" | jq '.'
    else
      echo "$JSON_ARRAY" | jq -r '.[] | "\(.ledger_id // "-") | \(.agent) | \(.event.type) | \(.ts)"'
    fi
    ;;
    
  *)
    echo "❌ Unknown mode: $MODE" >&2
    usage
    ;;
esac
