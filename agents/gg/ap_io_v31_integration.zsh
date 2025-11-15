#!/usr/bin/env zsh
# GG AP/IO v3.1 Integration (Read-Only)
# Purpose: Handle AP/IO v3.1 events for GG (cloud orchestrator, read-only)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools/ap_io_v31"

usage() {
  cat >&2 <<EOF
Usage: $0 <priority> [event_json]

  priority   - Event priority (critical, high, normal, low)
  event_json - Event JSON (if not provided, read from stdin)

Note: GG is read-only (cloud orchestrator), does not write events.
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

# Parse event
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required" >&2
  exit 1
fi

EVENT_TYPE=$(echo "$EVENT_JSON" | jq -r '.event.type // ""')
CORR_ID=$(echo "$EVENT_JSON" | jq -r '.correlation_id // ""')

# Handle event based on type (read-only operations)
case "$EVENT_TYPE" in
  correlation_query)
    # GG can query correlations for system overview
    if [ -n "$CORR_ID" ]; then
      echo "🔍 GG querying correlation: $CORR_ID" >&2
      # Query all agent ledgers for correlated events
      LEDGER_DATE=$(date +%Y-%m-%d)
      for agent in cls andy hybrid liam; do
        LEDGER_FILE="$REPO_ROOT/g/ledger/$agent/$LEDGER_DATE.jsonl"
        if [ -f "$LEDGER_FILE" ] && [ -f "$TOOLS_DIR/reader.zsh" ]; then
          echo "=== $agent ===" >&2
          "$TOOLS_DIR/reader.zsh" "$LEDGER_FILE" --correlation "$CORR_ID" 2>/dev/null || true
        fi
      done
    fi
    ;;
    
  info)
    # GG can read info events for system overview
    echo "ℹ️  GG received info event (read-only)" >&2
    ;;
    
  *)
    echo "ℹ️  GG received event: $EVENT_TYPE (read-only, no action)" >&2
    ;;
esac

exit 0
