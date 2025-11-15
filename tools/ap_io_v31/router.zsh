#!/usr/bin/env zsh
# AP/IO v3.1 Router
# Purpose: Route events to target agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <event_file> [options]

Options:
  --targets <agent1,agent2>  Target agents (overrides event routing)
  --broadcast                Broadcast to all agents
  --priority <level>        Priority (critical, high, normal, low)

Example:
  $0 event.json
  $0 event.json --targets cls,andy
  $0 event.json --broadcast --priority high
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

EVENT_FILE="$1"
shift

TARGETS_OVERRIDE=""
BROADCAST_OVERRIDE=""
PRIORITY_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets)
      TARGETS_OVERRIDE="$2"
      shift 2
      ;;
    --broadcast)
      BROADCAST_OVERRIDE="true"
      shift
      ;;
    --priority)
      PRIORITY_OVERRIDE="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Check file exists
if [ ! -f "$EVENT_FILE" ]; then
  echo "❌ Event file not found: $EVENT_FILE" >&2
  exit 1
fi

# Check jq availability
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required for routing" >&2
  exit 1
fi

# Read event
EVENT=$(cat "$EVENT_FILE")

# Determine targets
if [ -n "$TARGETS_OVERRIDE" ]; then
  TARGETS=$(echo "$TARGETS_OVERRIDE" | tr ',' ' ')
elif [ "$BROADCAST_OVERRIDE" = "true" ] || [ "$(echo "$EVENT" | jq -r '.routing.broadcast // false')" = "true" ]; then
  TARGETS=("cls" "andy" "hybrid" "liam" "gg" "kim")
else
  TARGETS=$(echo "$EVENT" | jq -r '.routing.targets[] // []' | tr '\n' ' ')
fi

# Determine priority
if [ -n "$PRIORITY_OVERRIDE" ]; then
  PRIORITY="$PRIORITY_OVERRIDE"
else
  PRIORITY=$(echo "$EVENT" | jq -r '.routing.priority // "normal"')
fi

# Route to targets
DELIVERED=()
for target in $TARGETS; do
  # Check if agent integration exists
  AGENT_INTEGRATION="$REPO_ROOT/agents/$target/ap_io_v31_integration.zsh"
  
  if [ -f "$AGENT_INTEGRATION" ]; then
    # Deliver event to agent
    echo "$EVENT" | "$AGENT_INTEGRATION" "$PRIORITY" >/dev/null 2>&1 && DELIVERED+=("$target")
  else
    echo "⚠️  Agent integration not found: $target" >&2
  fi
done

# Update delivered_to in event
UPDATED_EVENT=$(echo "$EVENT" | jq --argjson delivered "$(printf '%s\n' "${DELIVERED[@]}" | jq -R . | jq -s .)" '.routing.delivered_to = $delivered')

echo "$UPDATED_EVENT"
echo "✅ Routed to: ${DELIVERED[*]}" >&2

exit 0
