#!/usr/bin/env zsh
# Liam AP/IO v3.1 Integration
# Purpose: Handle AP/IO v3.1 events for Liam (local orchestrator)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools/ap_io_v31"
WRITER="$TOOLS_DIR/writer.zsh"
ROUTER="$TOOLS_DIR/router.zsh"
STATUS_FILE="$REPO_ROOT/agents/liam/status.json"

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
CORR_ID=$(echo "$EVENT_JSON" | jq -r '.correlation_id // ""')

# Handle event based on type
case "$EVENT_TYPE" in
  task_start)
    # Update Liam status to busy
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
    
    # Write orchestration event
    if [ -f "$WRITER" ]; then
      "$WRITER" liam info "$TASK_ID" "liam" "Orchestration started: $TASK_ID" "{\"status\":\"acknowledged\",\"priority\":\"$PRIORITY\"}" >/dev/null 2>&1 || true
    fi
    ;;
    
  task_result)
    # Update Liam status to idle
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
    # Handle routing request - Liam can route events
    if [ -f "$ROUTER" ]; then
      TMP_EVENT=$(mktemp)
      echo "$EVENT_JSON" > "$TMP_EVENT"
      "$ROUTER" "$TMP_EVENT" --priority "$PRIORITY" >/dev/null 2>&1 || true
      rm -f "$TMP_EVENT"
    fi
    ;;
    
  correlation_query)
    # Handle correlation query - Liam can query across agents
    if [ -n "$CORR_ID" ]; then
      echo "🔍 Liam querying correlation: $CORR_ID" >&2
      # Query all agent ledgers for correlated events
      LEDGER_DATE=$(date +%Y-%m-%d)
      for agent in cls andy hybrid liam; do
        LEDGER_FILE="$REPO_ROOT/g/ledger/$agent/$LEDGER_DATE.jsonl"
        if [ -f "$LEDGER_FILE" ] && [ -f "$TOOLS_DIR/reader.zsh" ]; then
          "$TOOLS_DIR/reader.zsh" "$LEDGER_FILE" --correlation "$CORR_ID" 2>/dev/null || true
        fi
      done
    fi
    ;;
    
  *)
    echo "ℹ️  Liam received event: $EVENT_TYPE" >&2
    ;;
esac

exit 0
