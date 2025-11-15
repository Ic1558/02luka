#!/usr/bin/env zsh
# AP/IO v3.1 Reader Stub
# Purpose: Read and parse AP/IO v3.1 and v1.0 ledger entries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# tools/ap_io_v31 -> tools -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <ledger_file> [options]

Options:
  --format json|pretty    Output format (default: json)
  --filter <field>=<value> Filter entries
  --agent <agent>         Filter by agent
  --event <type>          Filter by event type
  --correlation <id>      Filter by correlation ID
  --parent <id>           Filter by parent_id

Example:
  $0 g/ledger/cls/2025-11-16.jsonl
  $0 g/ledger/cls/2025-11-16.jsonl --format pretty
  $0 g/ledger/cls/2025-11-16.jsonl --agent cls --event task_result
  $0 g/ledger/cls/2025-11-16.jsonl --parent parent-wo-wo-251116-test
EOF
  exit 1
}

# Parse arguments
[[ $# -lt 1 ]] && usage

LEDGER_FILE="$1"
shift

FORMAT="json"
FILTER_AGENT=""
FILTER_EVENT=""
FILTER_CORR=""
FILTER_PARENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --agent)
      FILTER_AGENT="$2"
      shift 2
      ;;
    --event)
      FILTER_EVENT="$2"
      shift 2
      ;;
    --correlation)
      FILTER_CORR="$2"
      shift 2
      ;;
    --parent)
      FILTER_PARENT="$2"
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
  echo "❌ jq is required for reading ledger entries" >&2
  exit 1
fi

# Read and parse entries
while IFS= read -r line; do
  # Skip empty lines
  [ -z "$line" ] && continue
  
  # Detect protocol version
  if echo "$line" | jq -e '.protocol == "AP/IO" and .version == "3.1"' >/dev/null 2>&1; then
    # AP/IO v3.1 format
    ENTRY="$line"
  elif echo "$line" | jq -e '.ts and .agent and .event' >/dev/null 2>&1; then
    # Legacy v1.0 format - convert to v3.1 structure
    ENTRY=$(echo "$line" | jq -c '{
      protocol: "AP/IO",
      version: "1.0",
      ts: .ts,
      agent: .agent,
      session_id: .session_id // "",
      event: {
        type: .event,
        task_id: .task_id // "",
        source: .source // "system",
        summary: .summary // ""
      },
      data: {
        status: .data.status // "",
        duration_sec: .data.duration_sec // 0,
        files_touched: .data.files_touched // []
      }
    }')
  else
    # Skip malformed entries
    continue
  fi
  
  # Apply filters
  if [ -n "$FILTER_AGENT" ]; then
    if ! echo "$ENTRY" | jq -e ".agent == \"$FILTER_AGENT\"" >/dev/null 2>&1; then
      continue
    fi
  fi
  
  if [ -n "$FILTER_EVENT" ]; then
    if ! echo "$ENTRY" | jq -e ".event.type == \"$FILTER_EVENT\"" >/dev/null 2>&1; then
      continue
    fi
  fi
  
  if [ -n "$FILTER_CORR" ]; then
    if ! echo "$ENTRY" | jq -e ".correlation_id == \"$FILTER_CORR\"" >/dev/null 2>&1; then
      continue
    fi
  fi
  
  if [ -n "$FILTER_PARENT" ]; then
    if ! echo "$ENTRY" | jq -e ".parent_id == \"$FILTER_PARENT\"" >/dev/null 2>&1; then
      continue
    fi
  fi
  
  # Output
  if [ "$FORMAT" = "pretty" ]; then
    echo "$ENTRY" | jq '.'
  else
    echo "$ENTRY"
  fi
  
done < "$LEDGER_FILE"

exit 0
