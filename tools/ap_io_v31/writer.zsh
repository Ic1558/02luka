#!/usr/bin/env zsh
# AP/IO v3.1 Writer
# Purpose: Append-only writer for AP/IO v3.1 protocol events with improvements

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
# tools/ap_io_v31 -> tools -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA_DIR="$REPO_ROOT/schemas"
VALIDATOR="$SCRIPT_DIR/validator.zsh"
CORRELATION_ID="$SCRIPT_DIR/correlation_id.zsh"

# Configuration
MAX_WRITE_RETRIES="${MAX_WRITE_RETRIES:-3}"
WRITE_RETRY_DELAY="${WRITE_RETRY_DELAY:-0.1}"

usage() {
  cat >&2 <<EOF
Usage: $0 <agent> <event_type> <task_id> <source> <summary> [data_json] [parent_id] [execution_duration_ms]

Arguments:
  agent                - Agent identifier (cls, andy, hybrid, liam, gg, kim)
  event_type           - Event type (heartbeat, task_start, task_result, error, info)
  task_id              - Task identifier (e.g., wo-YYYYMMDD-task-name)
  source               - Event source (gg_orchestrator, kim, cursor, launchd, boss, system)
  summary              - Human-readable summary
  data_json            - Optional JSON data object
  parent_id            - Optional parent ID (format: parent-<type>-<id>)
  execution_duration_ms - Optional execution duration in milliseconds

Example:
  $0 cls task_start "wo-251116-test" "gg_orchestrator" "Starting test task" '{"status":"started"}'
  $0 cls task_result "wo-251116-test" "gg_orchestrator" "Task completed" '{"status":"success"}' "parent-wo-wo-251116-test" 1250
EOF
  exit 1
}

# Validate arguments
[[ $# -lt 5 ]] && usage

AGENT="$1"
EVENT_TYPE="$2"
TASK_ID="$3"
SOURCE="$4"
SUMMARY="$5"
DATA_JSON="${6:-{}}"
PARENT_ID="${7:-}"
EXECUTION_DURATION_MS="${8:-}"

# Validate agent
case "$AGENT" in
  cls|andy|hybrid|liam|gg|kim)
    ;;
  *)
    echo "❌ Invalid agent: $AGENT" >&2
    exit 1
    ;;
esac

# Validate event type
case "$EVENT_TYPE" in
  heartbeat|task_start|task_result|error|info|routing_request|correlation_query)
    ;;
  *)
    echo "❌ Invalid event type: $EVENT_TYPE" >&2
    exit 1
    ;;
esac

# Generate timestamp
TS=$(date -u +"%Y-%m-%dT%H:%M:%S+07:00" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S+07:00")

# Generate correlation ID
if [ -f "$CORRELATION_ID" ]; then
  CORR_ID=$("$CORRELATION_ID" 2>/dev/null || echo "corr-$(date +%Y%m%d)-001")
else
  CORR_ID="corr-$(date +%Y%m%d)-001"
fi

# Generate session ID (simplified)
SESSION_ID="$(date +%Y-%m-%d)_${AGENT}_001"

# Generate ledger_id (format: ledger-YYYYMMDD-HHMMSS-<agent>-<seq>)
LEDGER_DATE=$(date +%Y%m%d)
LEDGER_TIME=$(date +%H%M%S)
LEDGER_DATE_FMT=$(date +%Y-%m-%d)  # For file path (YYYY-MM-DD format)

# Get sequence number from existing ledger file (if exists)
# Support test isolation via LEDGER_BASE_DIR environment variable
LEDGER_BASE_DIR="${LEDGER_BASE_DIR:-$REPO_ROOT/g/ledger}"
LEDGER_DIR="$LEDGER_BASE_DIR/$AGENT"
LEDGER_FILE="$LEDGER_DIR/$LEDGER_DATE_FMT.jsonl"
SEQ=1
if [[ -f "$LEDGER_FILE" ]]; then
  # Count existing entries for today with same timestamp prefix
  PREFIX="ledger-${LEDGER_DATE}-${LEDGER_TIME}-${AGENT}-"
  COUNT=$(grep -c "\"ledger_id\":\"${PREFIX}" "$LEDGER_FILE" 2>/dev/null || echo "0")
  # Ensure COUNT is numeric
  if [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    SEQ=$((COUNT + 1))
  else
    SEQ=1
  fi
fi

LEDGER_ID="ledger-${LEDGER_DATE}-${LEDGER_TIME}-${AGENT}-$(printf "%03d" $SEQ)"

# Ensure ledger directory exists
mkdir -p "$LEDGER_DIR"

# Parse and validate DATA_JSON
if [ -z "$DATA_JSON" ] || [ "$DATA_JSON" = "{}" ]; then
  DATA_JSON="{}"
else
  # Validate JSON syntax
  if ! echo "$DATA_JSON" | jq empty 2>/dev/null; then
    echo "⚠️  Warning: Invalid JSON in data_json, using empty object" >&2
    DATA_JSON="{}"
  fi
fi

# Build event object
EVENT_OBJ=$(jq -n \
  --arg type "$EVENT_TYPE" \
  --arg task_id "$TASK_ID" \
  --arg source "$SOURCE" \
  --arg summary "$SUMMARY" \
  --argjson data "$DATA_JSON" \
  '{type: $type, task_id: $task_id, source: $source, summary: $summary, data: $data}')

# Build ledger entry with all fields
ENTRY=$(jq -n -c \
  --arg protocol "AP/IO" \
  --arg version "3.1" \
  --arg agent "$AGENT" \
  --arg ts "$TS" \
  --arg correlation_id "$CORR_ID" \
  --arg session_id "$SESSION_ID" \
  --arg ledger_id "$LEDGER_ID" \
  --arg parent_id "$PARENT_ID" \
  --argjson execution_duration_ms "$EXECUTION_DURATION_MS" \
  --argjson event "$EVENT_OBJ" \
  '{
    protocol: $protocol,
    version: $version,
    agent: $agent,
    ts: $ts,
    correlation_id: $correlation_id,
    session_id: $session_id,
    ledger_id: $ledger_id,
    parent_id: ($parent_id | if . == "" then null else . end),
    execution_duration_ms: ($execution_duration_ms | if . == "" then null else (. | tonumber) end),
    event: $event
  } | del(.[] | select(. == null))')

# Atomic write with retry logic
write_entry_atomic() {
  local entry="$1"
  local ledger_file="$2"
  local temp_file="${ledger_file}.tmp.$$"
  local retry=0
  
  while [ $retry -lt $MAX_WRITE_RETRIES ]; do
    # Write to temp file first
    if echo "$entry" >> "$temp_file" 2>/dev/null; then
      # Atomic move
      if mv "$temp_file" "$ledger_file" 2>/dev/null; then
        return 0
      else
        rm -f "$temp_file" 2>/dev/null
        if [ $retry -lt $((MAX_WRITE_RETRIES - 1)) ]; then
          sleep "$WRITE_RETRY_DELAY"
        fi
      fi
    else
      # Check for disk full
      if [ $? -eq 28 ] || df "$(dirname "$ledger_file")" | tail -1 | awk '{if ($4 < 1024) exit 1}'; then
        echo "❌ Disk full or write error" >&2
        rm -f "$temp_file" 2>/dev/null
        return 1
      fi
      if [ $retry -lt $((MAX_WRITE_RETRIES - 1)) ]; then
        sleep "$WRITE_RETRY_DELAY"
      fi
    fi
    ((retry++))
  done
  
  rm -f "$temp_file" 2>/dev/null
  echo "❌ Failed to write ledger entry after $MAX_WRITE_RETRIES retries" >&2
  return 1
}

# Validate entry before writing (if validator exists)
if [ -f "$VALIDATOR" ] && [ -x "$VALIDATOR" ]; then
  if ! echo "$ENTRY" | "$VALIDATOR" - 2>/dev/null; then
    echo "⚠️  Warning: Entry validation failed, but continuing" >&2
  fi
fi

# Write entry with atomic write and retry
if write_entry_atomic "$ENTRY" "$LEDGER_FILE"; then
  echo "✅ Ledger entry written: $LEDGER_ID"
  exit 0
else
  echo "❌ Failed to write ledger entry" >&2
  exit 1
fi
