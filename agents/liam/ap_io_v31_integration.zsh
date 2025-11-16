#!/usr/bin/env zsh
# Liam AP/IO v3.1 Integration
# Purpose: Handle AP/IO v3.1 events for Liam orchestrator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATUS_FILE="$REPO_ROOT/agents/liam/status.json"

PRIORITY="${1:-normal}"
EVENT_JSON=$(cat)

if [ -z "$EVENT_JSON" ]; then
  echo "❌ No event JSON provided" >&2
  exit 1
fi

# Parse event type
EVENT_TYPE=$(echo "$EVENT_JSON" | jq -r '.event.type // ""')

if [ -z "$EVENT_TYPE" ] || [ "$EVENT_TYPE" = "null" ]; then
  echo "❌ Invalid event: missing type" >&2
  exit 1
fi

# Liam handles orchestration events
case "$EVENT_TYPE" in
  routing_request)
    # Liam can route events to other agents
    TARGETS=$(echo "$EVENT_JSON" | jq -r '.routing.targets // [] | join(",")')
    if [ -n "$TARGETS" ] && [ "$TARGETS" != "null" ]; then
      ROUTER="$REPO_ROOT/tools/ap_io_v31/router.zsh"
      if [ -f "$ROUTER" ]; then
        echo "$EVENT_JSON" | "$ROUTER" - --targets "$TARGETS" --priority "$PRIORITY"
      fi
    fi
    ;;
  task_start|task_result)
    # Update status
    mkdir -p "$(dirname "$STATUS_FILE")"
    STATE="busy"
    if [ "$EVENT_TYPE" = "task_result" ]; then
      STATE="idle"
    fi
    jq -n \
      --arg agent "liam" \
      --arg state "$STATE" \
      --arg protocol "AP/IO" \
      --arg version "3.1" \
      --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S+07:00")" \
      --arg task_id "$(echo "$EVENT_JSON" | jq -r '.event.task_id // ""')" \
      '{
        agent: $agent,
        state: $state,
        protocol: $protocol,
        protocol_version: $version,
        last_heartbeat: $timestamp,
        last_task_id: $task_id
      }' > "$STATUS_FILE"
    ;;
esac

exit 0
