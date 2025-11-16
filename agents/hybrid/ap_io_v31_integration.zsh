#!/usr/bin/env zsh
# Hybrid AP/IO v3.1 Integration
# Purpose: Handle AP/IO v3.1 events for Hybrid agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATUS_FILE="$REPO_ROOT/agents/hybrid/status.json"

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

# Update status based on event
case "$EVENT_TYPE" in
  task_start)
    mkdir -p "$(dirname "$STATUS_FILE")"
    jq -n \
      --arg agent "hybrid" \
      --arg state "busy" \
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
  task_result|error)
    mkdir -p "$(dirname "$STATUS_FILE")"
    jq -n \
      --arg agent "hybrid" \
      --arg state "idle" \
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
  heartbeat)
    if [ -f "$STATUS_FILE" ]; then
      jq --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S+07:00")" \
        '.last_heartbeat = $timestamp' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && \
        mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
    fi
    ;;
esac

exit 0
