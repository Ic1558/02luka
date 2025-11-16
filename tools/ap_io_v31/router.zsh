#!/usr/bin/env zsh
# AP/IO v3.1 Router
# Purpose: Route events to target agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
# tools/ap_io_v31 -> tools -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <event_file> [options]

Options:
  --targets <agent1,agent2>  Target agents (overrides event routing)
  --priority <high|normal|low>  Event priority (default: normal)
  --broadcast                 Broadcast to all agents
  --help                      Show this help

Examples:
  $0 event.json
  $0 event.json --targets cls,andy
  $0 event.json --broadcast
EOF
  exit 1
}

# Parse arguments
EVENT_FILE=""
TARGETS=""
PRIORITY="normal"
BROADCAST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets)
      TARGETS="$2"
      shift 2
      ;;
    --priority)
      PRIORITY="$2"
      shift 2
      ;;
    --broadcast)
      BROADCAST=true
      shift
      ;;
    --help)
      usage
      ;;
    *)
      if [ -z "$EVENT_FILE" ]; then
        EVENT_FILE="$1"
      else
        echo "❌ Unknown option: $1" >&2
        usage
      fi
      shift
      ;;
  esac
done

# Validate event file
if [ -z "$EVENT_FILE" ] || [ ! -f "$EVENT_FILE" ]; then
  echo "❌ Error: Event file required and must exist" >&2
  usage
fi

# Read and validate event
if ! jq empty "$EVENT_FILE" 2>/dev/null; then
  echo "❌ Error: Invalid JSON in event file" >&2
  exit 1
fi

# Determine target agents
if [ "$BROADCAST" = true ]; then
  TARGET_LIST=("cls" "andy" "hybrid" "liam" "gg")
elif [ -n "$TARGETS" ]; then
  IFS=',' read -rA TARGET_LIST <<< "$TARGETS"
else
  # Extract from event routing field if present
  ROUTING=$(jq -r '.routing.targets // empty' "$EVENT_FILE" 2>/dev/null)
  if [ -n "$ROUTING" ] && [ "$ROUTING" != "null" ]; then
    IFS=',' read -rA TARGET_LIST <<< "$ROUTING"
  else
    echo "⚠️  Warning: No routing targets specified, using default: cls" >&2
    TARGET_LIST=("cls")
  fi
fi

# Route to each target agent
ROUTED=0
for target in "${TARGET_LIST[@]}"; do
  # Validate agent
  case "$target" in
    cls|andy|hybrid|liam|gg|kim)
      ;;
    *)
      echo "⚠️  Warning: Invalid agent: $target, skipping" >&2
      continue
      ;;
  esac
  
  # Check if agent integration exists
  AGENT_INTEGRATION="$REPO_ROOT/agents/$target/ap_io_v31_integration.zsh"
  if [ ! -f "$AGENT_INTEGRATION" ]; then
    echo "⚠️  Warning: Agent integration not found: $AGENT_INTEGRATION" >&2
    continue
  fi
  
  # Route event (call agent integration)
  if [ -x "$AGENT_INTEGRATION" ]; then
    if "$AGENT_INTEGRATION" route "$EVENT_FILE" "$PRIORITY" 2>/dev/null; then
      ((ROUTED++))
      echo "✅ Routed to $target"
    else
      echo "⚠️  Warning: Failed to route to $target" >&2
    fi
  else
    echo "⚠️  Warning: Agent integration not executable: $AGENT_INTEGRATION" >&2
  fi
done

if [ $ROUTED -eq 0 ]; then
  echo "❌ Error: No events routed successfully" >&2
  exit 1
fi

echo "✅ Routed $ROUTED event(s) to agent(s)"
exit 0
