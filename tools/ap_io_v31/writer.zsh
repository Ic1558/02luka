#!/usr/bin/env zsh
# AP/IO v3.1 Writer Stub
# Purpose: Append-only writer for AP/IO v3.1 protocol events

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCHEMA_DIR="$REPO_ROOT/schemas"
VALIDATOR="$SCRIPT_DIR/validator.zsh"
CORRELATION_ID="$SCRIPT_DIR/correlation_id.zsh"

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
# Get sequence number from existing ledger file (if exists)
LEDGER_DIR="$REPO_ROOT/g/ledger/$AGENT"
LEDGER_FILE="$LEDGER_DIR/$(date +%Y-%m-%d).jsonl"
SEQ=1
if [[ -f "$LEDGER_FILE" ]]; then
  # Count existing entries for today with same timestamp prefix
  PREFIX="ledger-${LEDGER_DATE}-${LEDGER_TIME}-${AGENT}-"
  SEQ=$(grep -c "\"ledger_id\":\"${PREFIX}" "$LEDGER_FILE" 2>/dev/null || echo "0")
  SEQ=$((SEQ + 1))
fi
LEDGER_ID="ledger-${LEDGER_DATE}-${LEDGER_TIME}-${AGENT}-${SEQ}"

# Add execution_duration_ms to data_json if provided
if [[ -n "$EXECUTION_DURATION_MS" ]]; then
  # Parse existing data_json and add execution_duration_ms
  if [[ "$DATA_JSON" == "{}" ]]; then
    DATA_JSON="{\"execution_duration_ms\":${EXECUTION_DURATION_MS}}"
  else
    # Use jq to add the field if available, otherwise use sed
    if command -v jq >/dev/null 2>&1; then
      DATA_JSON=$(echo "$DATA_JSON" | jq -c ". + {\"execution_duration_ms\":${EXECUTION_DURATION_MS}}")
    else
      # Fallback: append to JSON (simple approach)
      DATA_JSON="${DATA_JSON%,*},\"execution_duration_ms\":${EXECUTION_DURATION_MS}}"
    fi
  fi
fi

# Build ledger entry with optional fields
if [[ -n "$PARENT_ID" ]]; then
  LEDGER_ENTRY=$(cat <<EOF
{
  "protocol": "AP/IO",
  "version": "3.1",
  "ledger_id": "$LEDGER_ID",
  "parent_id": "$PARENT_ID",
  "ts": "$TS",
  "agent": "$AGENT",
  "correlation_id": "$CORR_ID",
  "session_id": "$SESSION_ID",
  "event": {
    "type": "$EVENT_TYPE",
    "task_id": "$TASK_ID",
    "source": "$SOURCE",
    "summary": "$SUMMARY"
  },
  "data": $DATA_JSON,
  "routing": {
    "targets": ["$AGENT"],
    "broadcast": false,
    "priority": "normal",
    "delivered_to": []
  }
}
EOF
)
else
  LEDGER_ENTRY=$(cat <<EOF
{
  "protocol": "AP/IO",
  "version": "3.1",
  "ledger_id": "$LEDGER_ID",
  "ts": "$TS",
  "agent": "$AGENT",
  "correlation_id": "$CORR_ID",
  "session_id": "$SESSION_ID",
  "event": {
    "type": "$EVENT_TYPE",
    "task_id": "$TASK_ID",
    "source": "$SOURCE",
    "summary": "$SUMMARY"
  },
  "data": $DATA_JSON,
  "routing": {
    "targets": ["$AGENT"],
    "broadcast": false,
    "priority": "normal",
    "delivered_to": []
  }
}
EOF
)
fi

# Validate entry
if [ -f "$VALIDATOR" ]; then
  if ! echo "$LEDGER_ENTRY" | "$VALIDATOR" - 2>/dev/null; then
    echo "❌ Validation failed" >&2
    exit 1
  fi
fi

# Determine ledger file (already set above for sequence calculation)
LEDGER_DATE=$(date +%Y-%m-%d)

# Create directory if missing
mkdir -p "$LEDGER_DIR"

# Append to ledger (append-only, never overwrite)
echo "$LEDGER_ENTRY" >> "$LEDGER_FILE"

echo "✅ Written to $LEDGER_FILE"
exit 0
