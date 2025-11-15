#!/usr/bin/env zsh
# Agent Ledger Writer - Append-Only Event Logger
# Usage: ledger_write.zsh <agent> <event_type> <task_id> <source> <summary> [data_json]
# Example: ledger_write.zsh cls task_start "wo-123" "gg_orchestrator" "Task description" '{"key":"value"}'

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ledger_write.zsh <agent> <event_type> <task_id> <source> <summary> [data_json]

Arguments:
  agent       Agent name (cls, andy, hybrid, gg, etc.)
  event_type  Event type (heartbeat, task_start, task_result, error, info)
  task_id     Task identifier (e.g., wo-251116-agents-layout)
  source      Source of event (e.g., gg_orchestrator, user, system)
  summary     Human-readable summary
  data_json   Optional JSON object with additional data

Examples:
  ledger_write.zsh cls task_start "wo-123" "gg_orchestrator" "Starting task"
  ledger_write.zsh cls task_result "wo-123" "gg_orchestrator" "Task completed" '{"status":"success","duration_sec":120}'
USAGE
  exit 1
}

[[ $# -lt 5 ]] && usage

AGENT="$1"
EVENT_TYPE="$2"
TASK_ID="$3"
SOURCE="$4"
SUMMARY="$5"
DATA_JSON="${6:-{}}"

# Validate agent name (filesystem-safe)
if [[ ! "$AGENT" =~ ^[a-z0-9_-]+$ ]]; then
  echo "Error: Invalid agent name: $AGENT (must be lowercase alphanumeric, underscore, hyphen)" >&2
  exit 1
fi

# Validate event type
case "$EVENT_TYPE" in
  heartbeat|task_start|task_result|error|info)
    ;;
  *)
    echo "Error: Invalid event_type: $EVENT_TYPE" >&2
    echo "Valid types: heartbeat, task_start, task_result, error, info" >&2
    exit 1
    ;;
esac

# Get paths
REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
LEDGER_DIR="$REPO_ROOT/g/ledger/$AGENT"
DATE=$(date '+%Y-%m-%d')
LEDGER_FILE="$LEDGER_DIR/$DATE.jsonl"

# Auto-create directory
mkdir -p "$LEDGER_DIR"

# Validate JSON if provided
if [[ "$DATA_JSON" != "{}" ]]; then
  if ! echo "$DATA_JSON" | python3 -m json.tool >/dev/null 2>&1; then
    echo "Error: Invalid JSON in data_json: $DATA_JSON" >&2
    exit 1
  fi
fi

# Generate session ID (YYYY-MM-DD_agent_NNN format)
SESSION_ID_FILE="$REPO_ROOT/memory/$AGENT/sessions/.last_session_id"
SESSION_COUNTER=1
if [[ -f "$SESSION_ID_FILE" ]]; then
  LAST_DATE=$(head -1 "$SESSION_ID_FILE" 2>/dev/null || echo "")
  if [[ "$LAST_DATE" == "$DATE" ]]; then
    SESSION_COUNTER=$(tail -1 "$SESSION_ID_FILE" 2>/dev/null | awk '{print $2+1}' || echo "1")
  fi
fi
SESSION_ID="${DATE}_${AGENT}_$(printf "%03d" "$SESSION_COUNTER")"
echo -e "$DATE\n$SESSION_COUNTER" > "$SESSION_ID_FILE"

# Build ledger entry
TIMESTAMP=$(date -Iseconds)
LEDGER_ENTRY=$(python3 <<PY
import json
import sys

entry = {
    "ts": "$TIMESTAMP",
    "agent": "$AGENT",
    "session_id": "$SESSION_ID",
    "event": "$EVENT_TYPE",
    "task_id": "$TASK_ID",
    "source": "$SOURCE",
    "summary": "$SUMMARY",
    "data": json.loads('$DATA_JSON')
}

# Validate and output
json.dump(entry, sys.stdout, ensure_ascii=False)
PY
)

# Validate JSON before writing
if ! echo "$LEDGER_ENTRY" | python3 -m json.tool >/dev/null 2>&1; then
  echo "Error: Generated invalid JSON entry" >&2
  exit 1
fi

# Append-only write (>>) - never overwrite (>)
# Check if file exists and is writable
if [[ -f "$LEDGER_FILE" ]] && [[ ! -w "$LEDGER_FILE" ]]; then
  echo "Error: Ledger file exists but is not writable: $LEDGER_FILE" >&2
  exit 1
fi

# Append entry (append-only pattern)
echo "$LEDGER_ENTRY" >> "$LEDGER_FILE" || {
  echo "Error: Failed to write ledger entry to $LEDGER_FILE" >&2
  exit 1
}

# Verify write succeeded
if [[ ! -f "$LEDGER_FILE" ]] || ! tail -1 "$LEDGER_FILE" | python3 -m json.tool >/dev/null 2>&1; then
  echo "Error: Ledger write verification failed" >&2
  exit 1
fi

echo "✅ Ledger entry written: $LEDGER_FILE"
