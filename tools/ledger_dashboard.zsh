#!/usr/bin/env zsh
# Agent Ledger Dashboard - Query and display ledger data
# Usage: ledger_dashboard.zsh [agent] [date] [event_type]
# Example: ledger_dashboard.zsh cls 2025-11-16 task_result

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
LEDGER_DIR="$REPO_ROOT/g/ledger"

AGENT="${1:-all}"
DATE="${2:-$(date +%Y-%m-%d)}"
EVENT_TYPE="${3:-all}"

echo "=== Agent Ledger Dashboard ==="
echo "Date: $DATE"
echo "Agent: $AGENT"
echo "Event Type: $EVENT_TYPE"
echo ""

if [[ "$AGENT" == "all" ]]; then
  AGENTS=$(ls -1 "$LEDGER_DIR" 2>/dev/null | grep -v "^$")
else
  AGENTS="$AGENT"
fi

for agent in $AGENTS; do
  LEDGER_FILE="$LEDGER_DIR/$agent/$DATE.jsonl"
  if [[ ! -f "$LEDGER_FILE" ]]; then
    continue
  fi
  
  echo "--- $agent ---"
  
  if [[ "$EVENT_TYPE" == "all" ]]; then
    COUNT=$(wc -l < "$LEDGER_FILE" | xargs)
    echo "Total entries: $COUNT"
    echo ""
    echo "Recent entries:"
    tail -5 "$LEDGER_FILE" | while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        echo "$line" | python3 -c "import json, sys; d=json.load(sys.stdin); print(f\"  [{d.get('ts', '')}] {d.get('event', '')}: {d.get('summary', '')}\")" 2>/dev/null || echo "  $line"
      fi
    done
  else
    grep "\"event\":\"$EVENT_TYPE\"" "$LEDGER_FILE" | tail -5 | while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        echo "$line" | python3 -c "import json, sys; d=json.load(sys.stdin); print(f\"  [{d.get('ts', '')}] {d.get('summary', '')}\")" 2>/dev/null || echo "  $line"
      fi
    done
  fi
  echo ""
done

echo "=== Status Files ==="
for agent in $AGENTS; do
  STATUS_FILE="$REPO_ROOT/agents/$agent/status.json"
  if [[ -f "$STATUS_FILE" ]]; then
    echo "--- $agent status ---"
    cat "$STATUS_FILE" | python3 -c "import json, sys; d=json.load(sys.stdin); print(f\"  State: {d.get('state', 'unknown')}\"); print(f\"  Last Task: {d.get('last_task_id', 'none')}\"); print(f\"  Updated: {d.get('updated_at', 'unknown')}\")" 2>/dev/null || cat "$STATUS_FILE"
    echo ""
  fi
done
