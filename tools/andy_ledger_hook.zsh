#!/usr/bin/env zsh
# Andy Ledger Hook - Integration with Codex CLI execution
# Usage: andy_ledger_hook.zsh <event_type> <task_id> <summary> [data_json]
# This is called by Andy/Codex tools to write ledger entries

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
LEDGER_TOOL="$REPO_ROOT/tools/ledger_write.zsh"
STATUS_TOOL="$REPO_ROOT/tools/status_update.zsh"

# Default values
AGENT="andy"
SOURCE="codex_cli"
TASK_ID="${2:-unknown}"
SUMMARY="${3:-}"
DATA_JSON="${4:-{}}"

case "${1:-}" in
  task_start)
    EVENT_TYPE="task_start"
    STATE="busy"
    ;;
  task_result)
    EVENT_TYPE="task_result"
    STATE="idle"
    ;;
  error)
    EVENT_TYPE="error"
    STATE="error"
    ;;
  heartbeat)
    EVENT_TYPE="heartbeat"
    STATE="idle"
    ;;
  info)
    EVENT_TYPE="info"
    STATE="idle"
    ;;
  *)
    echo "Usage: andy_ledger_hook.zsh <event_type> <task_id> <summary> [data_json]" >&2
    echo "Event types: task_start, task_result, error, heartbeat, info" >&2
    exit 1
    ;;
esac

# Write ledger entry
if [[ -x "$LEDGER_TOOL" ]]; then
  "$LEDGER_TOOL" "$AGENT" "$EVENT_TYPE" "$TASK_ID" "$SOURCE" "$SUMMARY" "$DATA_JSON" || {
    echo "Warning: Ledger write failed (non-fatal)" >&2
  }
else
  echo "Warning: Ledger tool not found: $LEDGER_TOOL" >&2
fi

# Update status
if [[ -x "$STATUS_TOOL" ]]; then
  TIMESTAMP=$(date -Iseconds)
  DATE=$(date '+%Y-%m-%d')
  SESSION_ID_FILE="$REPO_ROOT/memory/$AGENT/sessions/.last_session_id"
  SESSION_COUNTER=1
  if [[ -f "$SESSION_ID_FILE" ]]; then
    LAST_DATE=$(head -1 "$SESSION_ID_FILE" 2>/dev/null || echo "")
    if [[ "$LAST_DATE" == "$DATE" ]]; then
      SESSION_COUNTER=$(tail -1 "$SESSION_ID_FILE" 2>/dev/null | awk '{print $2+1}' || echo "1")
    fi
  fi
  SESSION_ID="${DATE}_${AGENT}_$(printf "%03d" "$SESSION_COUNTER")"
  
  if [[ "$EVENT_TYPE" == "error" ]]; then
    ERROR_MSG=$(echo "$DATA_JSON" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('error', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
    "$STATUS_TOOL" "$AGENT" "$STATE" "$TIMESTAMP" "$TASK_ID" "$SESSION_ID" "$ERROR_MSG" || true
  else
    "$STATUS_TOOL" "$AGENT" "$STATE" "$TIMESTAMP" "$TASK_ID" "$SESSION_ID" || true
  fi
else
  echo "Warning: Status tool not found: $STATUS_TOOL" >&2
fi

echo "✅ Andy ledger hook executed: $EVENT_TYPE"
