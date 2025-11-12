#!/usr/bin/env zsh
set -euo pipefail

errors=()
ok() { echo "✅ $1"; }
ng() { errors+=("$1"); echo "❌ $1"; }

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"

test -d "$LUKA_SOT/shared_memory" && ok "shared_memory exists" || ng "shared_memory missing"
test -f "$LUKA_SOT/shared_memory/context.json" && ok "context.json exists" || ng "context.json missing"
jq . >/dev/null 2>&1 < "$LUKA_SOT/shared_memory/context.json" && ok "context.json valid JSON" || ng "context.json invalid"
test -x "$LUKA_SOT/tools/memory_sync.sh" && ok "memory_sync.sh executable" || ng "memory_sync.sh not executable"
test -x "$LUKA_SOT/tools/bridge_monitor.sh" && ok "bridge_monitor.sh executable" || ng "bridge_monitor.sh not executable"
launchctl list | grep -q com.02luka.memory.bridge && ok "LaunchAgent: bridge loaded" || ng "LaunchAgent: bridge not loaded"
test -x "$LUKA_SOT/tools/gc_memory_sync.sh" && ok "gc_memory_sync.sh executable" || ng "gc_memory_sync.sh not executable"
test -f "$LUKA_SOT/agents/cls_bridge/cls_memory.py" && ok "cls_memory.py exists" || ng "cls_memory.py missing"
launchctl list | grep -q com.02luka.memory.metrics && ok "LaunchAgent: metrics loaded" || ng "LaunchAgent: metrics not loaded"

if [ ${#errors[@]} -eq 0 ]; then
  ok "health passed"
  exit 0
else
  echo "Failures: ${errors[*]}"
  exit 1
fi
