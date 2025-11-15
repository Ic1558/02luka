#!/usr/bin/env zsh
# Hybrid AP/IO v3.1 Integration
# Purpose: Handle AP/IO v3.1 events for Hybrid/Luka CLI agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools/ap_io_v31"
WRITER="$TOOLS_DIR/writer.zsh"
STATUS_FILE="$REPO_ROOT/agents/hybrid/status.json"

usage() {
  cat >&2 <<EOF
Usage: $0 <priority> [event_json]

  priority   - Event priority (critical, high, normal, low)
  event_json - Event JSON (if not provided, read from stdin)
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

PRIORITY="$1"
shift

# Read event from stdin or argument
if [ $# -gt 0 ]; then
  EVENT_JSON="$1"
else
  EVENT_JSON=$(cat)
fi

# Validate priority
case "$PRIORITY" in
  critical|high|normal|low)
    ;;
  *)
    echo "❌ Invalid priority: $PRIORITY" >&2
    exit 1
    ;;
esac

# Parse event
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required" >&2
  exit 1
fi

EVENT_TYPE=$(echo "$EVENT_JSON" | jq -r '.event.type // ""')
TASK_ID=$(echo "$EVENT_JSON" | jq -r '.event.task_id // ""')

# Handle event based on type
case "$EVENT_TYPE" in
  task_start)
    # Update Hybrid status to busy
    if [ -f "$STATUS_FILE" ]; then
      STATUS_DATA=$(cat "$STATUS_FILE")
      UPDATED_STATUS=$(echo "$STATUS_DATA" | jq --arg state "busy" --arg task "$TASK_ID" --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%S+07:00")" '
        .state = $state |
        .last_task_id = $task |
        .last_heartbeat = $ts |
        .protocol = "AP/IO" |
        .protocol_version = "3.1"
      ')
      echo "$UPDATED_STATUS" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
    fi
    
    # Write acknowledgment
    if [ -f "$WRITER" ]; then
      "$WRITER" hybrid info "$TASK_ID" "hybrid" "WO execution started: $TASK_ID" "{\"status\":\"acknowledged\",\"priority\":\"$PRIORITY\"}" >/dev/null 2>&1 || true
    fi
    ;;
    
  task_result)
    # Update Hybrid status to idle
    if [ -f "$STATUS_FILE" ]; then
      STATUS_DATA=$(cat "$STATUS_FILE")
      UPDATED_STATUS=$(echo "$STATUS_DATA" | jq --arg state "idle" --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%S+07:00")" '
        .state = $state |
        .last_heartbeat = $ts
      ')
      echo "$UPDATED_STATUS" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
    fi
    ;;
    
  routing_request)
    # Handle routing request
    TARGETS=$(echo "$EVENT_JSON" | jq -r '.routing.targets[] // []')
    echo "📨 Hybrid received routing request for: $TARGETS" >&2
    ;;
    
  *)
    echo "ℹ️  Hybrid received event: $EVENT_TYPE" >&2
    ;;
esac

exit 0
