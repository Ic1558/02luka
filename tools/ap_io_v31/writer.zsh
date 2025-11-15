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
Usage: $0 <agent> <event_type> <task_id> <source> <summary> [data_json]

Arguments:
  agent      - Agent identifier (cls, andy, hybrid, liam, gg, kim)
  event_type - Event type (heartbeat, task_start, task_result, error, info)
  task_id    - Task identifier (e.g., wo-YYYYMMDD-task-name)
  source     - Event source (gg_orchestrator, kim, cursor, launchd, boss, system)
  summary    - Human-readable summary
  data_json  - Optional JSON data object

Example:
  $0 cls task_start "wo-251116-test" "gg_orchestrator" "Starting test task" '{"status":"started"}'
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

# Build ledger entry
LEDGER_ENTRY=$(cat <<EOF
{
  "protocol": "AP/IO",
  "version": "3.1",
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

# Validate entry
if [ -f "$VALIDATOR" ]; then
  if ! echo "$LEDGER_ENTRY" | "$VALIDATOR" - 2>/dev/null; then
    echo "❌ Validation failed" >&2
    exit 1
  fi
fi

# Determine ledger file
LEDGER_DATE=$(date +%Y-%m-%d)
LEDGER_DIR="$REPO_ROOT/g/ledger/$AGENT"
LEDGER_FILE="$LEDGER_DIR/$LEDGER_DATE.jsonl"

# Create directory if missing
mkdir -p "$LEDGER_DIR"

# Append to ledger (append-only, never overwrite)
echo "$LEDGER_ENTRY" >> "$LEDGER_FILE"

echo "✅ Written to $LEDGER_FILE"
exit 0

