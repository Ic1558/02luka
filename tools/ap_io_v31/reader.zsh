#!/usr/bin/env zsh
# AP/IO v3.1 Reader
# Purpose: Read and filter AP/IO v3.1 ledger entries with improvements

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
# tools/ap_io_v31 -> tools -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <ledger_file> [options]

Options:
  --agent <agent>           Filter by agent (cls, andy, hybrid, liam, gg, kim)
  --event-type <type>       Filter by event type
  --correlation <id>        Filter by correlation ID
  --parent <id>             Filter by parent ID
  --since <timestamp>        Filter entries since timestamp (ISO 8601)
  --until <timestamp>        Filter entries until timestamp (ISO 8601)
  --format <json|pretty>    Output format (default: json)
  --help                    Show this help

Examples:
  $0 g/ledger/cls/2025-11-17.jsonl
  $0 g/ledger/cls/2025-11-17.jsonl --agent cls --format pretty
  $0 g/ledger/cls/2025-11-17.jsonl --correlation corr-20251117-001
  $0 - --agent cls  # Read from stdin
EOF
  exit 1
}

# Parse arguments
LEDGER_FILE=""
AGENT_FILTER=""
EVENT_TYPE_FILTER=""
CORRELATION_FILTER=""
PARENT_FILTER=""
SINCE_FILTER=""
UNTIL_FILTER=""
OUTPUT_FORMAT="json"

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
    --parent)
      PARENT_FILTER="$2"
      shift 2
      ;;
    --since)
      SINCE_FILTER="$2"
      shift 2
      ;;
    --until)
      UNTIL_FILTER="$2"
      shift 2
      ;;
    --format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    -)
      # Read from stdin
      LEDGER_FILE="-"
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

# Validate ledger file
if [ -z "$LEDGER_FILE" ]; then
  echo "❌ Error: Ledger file required" >&2
  usage
fi

# Handle missing file gracefully (for stdin, this is OK)
if [ "$LEDGER_FILE" != "-" ] && [ ! -f "$LEDGER_FILE" ]; then
  echo "⚠️  Warning: Ledger file not found: $LEDGER_FILE" >&2
  exit 0  # Return empty result, not error
fi

# Read and filter entries
filter_entries() {
  local input="$1"
  
  # Build jq filter
  local jq_filter="."
  
  if [ -n "$AGENT_FILTER" ]; then
    jq_filter="$jq_filter | select(.agent == \"$AGENT_FILTER\")"
  fi
  
  if [ -n "$EVENT_TYPE_FILTER" ]; then
    jq_filter="$jq_filter | select(.event.type == \"$EVENT_TYPE_FILTER\")"
  fi
  
  if [ -n "$CORRELATION_FILTER" ]; then
    jq_filter="$jq_filter | select(.correlation_id == \"$CORRELATION_FILTER\")"
  fi
  
  if [ -n "$PARENT_FILTER" ]; then
    jq_filter="$jq_filter | select(.parent_id == \"$PARENT_FILTER\")"
  fi
  
  if [ -n "$SINCE_FILTER" ]; then
    jq_filter="$jq_filter | select(.ts >= \"$SINCE_FILTER\")"
  fi
  
  if [ -n "$UNTIL_FILTER" ]; then
    jq_filter="$jq_filter | select(.ts <= \"$UNTIL_FILTER\")"
  fi
  
  # Process input
  if [ "$input" = "-" ]; then
    # Read from stdin
    cat | jq -c "$jq_filter" 2>/dev/null || {
      echo "⚠️  Warning: Invalid JSON in input" >&2
      return 1
    }
  else
    # Read from file, handle large files efficiently
    if command -v jq >/dev/null 2>&1; then
      # Process line by line for large files
      while IFS= read -r line; do
        if [ -n "$line" ]; then
          echo "$line" | jq -c "$jq_filter" 2>/dev/null || true
        fi
      done < "$input"
    else
      echo "❌ Error: jq not found (required for filtering)" >&2
      exit 1
    fi
  fi
}

# Format output
format_output() {
  local format="$1"
  local data="$2"
  
  case "$format" in
    pretty)
      if command -v jq >/dev/null 2>&1; then
        echo "$data" | jq -s '.' | jq '.'
      else
        echo "$data"
      fi
      ;;
    json)
      echo "$data"
      ;;
    *)
      echo "$data"
      ;;
  esac
}

# Main processing
if [ "$LEDGER_FILE" = "-" ]; then
  # Read from stdin
  FILTERED=$(filter_entries "-")
else
  # Read from file
  FILTERED=$(filter_entries "$LEDGER_FILE")
fi

# Format and output
if [ -n "$FILTERED" ]; then
  format_output "$OUTPUT_FORMAT" "$FILTERED"
else
  # No results, but not an error
  exit 0
fi
