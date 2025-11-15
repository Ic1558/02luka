#!/usr/bin/env zsh
# Agent Status Updater - Safe Write Pattern (temp → mv)
# Usage: status_update.zsh <agent> <state> <last_heartbeat> [task_id] [session_id] [last_error]
# Example: status_update.zsh cls idle "2025-11-16T10:00:00+07:00" "wo-123" "2025-11-16_cls_001"

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: status_update.zsh <agent> <state> <last_heartbeat> [task_id] [session_id] [last_error]

Arguments:
  agent          Agent name (cls, andy, hybrid, gg, etc.)
  state          Agent state (idle, busy, error, offline)
  last_heartbeat ISO-8601 timestamp
  task_id        Optional: Current task ID
  session_id     Optional: Current session ID
  last_error     Optional: Last error message (if state=error)

Examples:
  status_update.zsh cls idle "2025-11-16T10:00:00+07:00"
  status_update.zsh cls busy "2025-11-16T10:05:00+07:00" "wo-123" "2025-11-16_cls_001"
  status_update.zsh cls error "2025-11-16T10:10:00+07:00" "" "" "Task failed"
USAGE
  exit 1
}

[[ $# -lt 3 ]] && usage

AGENT="$1"
STATE="$2"
LAST_HEARTBEAT="$3"
TASK_ID="${4:-}"
SESSION_ID="${5:-}"
LAST_ERROR="${6:-}"

# Validate agent name
if [[ ! "$AGENT" =~ ^[a-z0-9_-]+$ ]]; then
  echo "Error: Invalid agent name: $AGENT" >&2
  exit 1
fi

# Validate state
case "$STATE" in
  idle|busy|error|offline)
    ;;
  *)
    echo "Error: Invalid state: $STATE" >&2
    echo "Valid states: idle, busy, error, offline" >&2
    exit 1
    ;;
esac

# Validate timestamp format
if ! date -j -f "%Y-%m-%dT%H:%M:%S%z" "$LAST_HEARTBEAT" >/dev/null 2>&1 && \
   ! date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_HEARTBEAT%+*}" >/dev/null 2>&1; then
  echo "Warning: Timestamp format may be invalid: $LAST_HEARTBEAT" >&2
fi

# Get paths
REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
STATUS_DIR="$REPO_ROOT/agents/$AGENT"
STATUS_FILE="$STATUS_DIR/status.json"
TEMP_FILE="${STATUS_FILE}.tmp.$$"

# Auto-create directory
mkdir -p "$STATUS_DIR"

# Build status JSON
STATUS_JSON=$(python3 <<PY
import json
import sys

status = {
    "agent": "$AGENT",
    "state": "$STATE",
    "last_heartbeat": "$LAST_HEARTBEAT"
}

if "$TASK_ID":
    status["last_task_id"] = "$TASK_ID"

if "$SESSION_ID":
    status["session_id"] = "$SESSION_ID"

if "$STATE" == "error" and "$LAST_ERROR":
    status["last_error"] = "$LAST_ERROR"
else:
    status["last_error"] = None

json.dump(status, sys.stdout, indent=2, ensure_ascii=False)
PY
)

# Validate JSON
if ! echo "$STATUS_JSON" | python3 -m json.tool >/dev/null 2>&1; then
  echo "Error: Generated invalid JSON" >&2
  exit 1
fi

# Safe write pattern: temp → mv (atomic)
echo "$STATUS_JSON" > "$TEMP_FILE" || {
  echo "Error: Failed to write temp file: $TEMP_FILE" >&2
  exit 1
}

# Verify temp file is valid JSON
if ! python3 -m json.tool "$TEMP_FILE" >/dev/null 2>&1; then
  rm -f "$TEMP_FILE"
  echo "Error: Temp file contains invalid JSON" >&2
  exit 1
fi

# Atomic move (temp → final)
mv "$TEMP_FILE" "$STATUS_FILE" || {
  rm -f "$TEMP_FILE"
  echo "Error: Failed to move temp file to status.json" >&2
  exit 1
}

# Verify final file
if ! python3 -m json.tool "$STATUS_FILE" >/dev/null 2>&1; then
  echo "Error: Status file verification failed" >&2
  exit 1
fi

echo "✅ Status updated: $STATUS_FILE"
