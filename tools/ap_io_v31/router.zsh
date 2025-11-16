#!/usr/bin/env zsh
# AP/IO v3.1 Router
# Purpose: Route AP/IO v3.1 events to target agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <event_file> [options]

Options:
  --targets <agent1,agent2>  Target agents (comma-separated)
  --broadcast                Broadcast to all agents
  --priority <level>         Priority: critical, high, normal, low

Example:
  $0 event.json --targets cls,andy
  $0 event.json --broadcast --priority high
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

EVENT_FILE="$1"
shift

TARGETS=()
BROADCAST=false
PRIORITY="normal"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets)
      IFS=',' read -rA TARGETS <<< "$2"
      shift 2
      ;;
    --broadcast)
      BROADCAST=true
      shift
      ;;
    --priority)
      PRIORITY="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Read event
if [ ! -f "$EVENT_FILE" ]; then
  echo "❌ Event file not found: $EVENT_FILE" >&2
  exit 1
fi

EVENT=$(cat "$EVENT_FILE")

# Determine targets
if [ "$BROADCAST" = true ]; then
  TARGETS=("cls" "andy" "hybrid" "liam" "gg" "kim")
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "❌ No targets specified" >&2
  exit 1
fi

# Route to each target agent
for agent in "${TARGETS[@]}"; do
  INTEGRATION_SCRIPT="$REPO_ROOT/agents/$agent/ap_io_v31_integration.zsh"
  
  if [ -f "$INTEGRATION_SCRIPT" ]; then
    echo "$EVENT" | "$INTEGRATION_SCRIPT" "$PRIORITY" 2>&1
  else
    echo "⚠️  Integration script not found for agent: $agent" >&2
  fi
done

exit 0
