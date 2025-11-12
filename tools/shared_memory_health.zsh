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

# Phase 4 checks
test -f "$LUKA_SOT/agents/memory_hub/memory_hub.py" && ok "memory_hub.py exists" || ng "memory_hub.py missing"
launchctl list | grep -q com.02luka.memory.hub && ok "LaunchAgent: hub loaded" || ng "LaunchAgent: hub not loaded"
test -x "$LUKA_SOT/tools/mary_memory_hook.zsh" && ok "mary_memory_hook.zsh executable" || ng "mary_memory_hook.zsh not executable"
test -x "$LUKA_SOT/tools/rnd_memory_hook.zsh" && ok "rnd_memory_hook.zsh executable" || ng "rnd_memory_hook.zsh not executable"
command -v redis-cli >/dev/null 2>&1 && redis-cli -a changeme-02luka ping >/dev/null 2>&1 && ok "Redis: connected" || echo "ℹ️  Redis: not available (optional)"
