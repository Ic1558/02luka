#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
REDIS_PASS="changeme-02luka"
SCORE=0
MAX_SCORE=0
errors=()

ok() { echo "✅ $1"; SCORE=$((SCORE+1)); MAX_SCORE=$((MAX_SCORE+1)); }
ng() { echo "❌ $1"; MAX_SCORE=$((MAX_SCORE+1)); errors+=("$1"); }

echo "=== Memory Hub Health Check (Phase 4) ==="
echo ""

# Hub service
echo "Hub Service:"
launchctl list | grep -q com.02luka.memory.hub && ok "LaunchAgent loaded" || ng "LaunchAgent not loaded"
[[ -f "$REPO/agents/memory_hub/memory_hub.py" ]] && ok "Hub script exists" || ng "Hub script missing"
if [[ -f "$REPO/logs/memory_hub.out.log" ]]; then
  ok "Hub log exists"
else
  echo "ℹ️  Hub log not yet created (will be created on first run)"
  MAX_SCORE=$((MAX_SCORE+1))
fi
echo ""

# Redis connectivity
echo "Redis:"
if redis-cli -a "$REDIS_PASS" PING >/dev/null 2>&1; then
  ok "Redis connected"
else
  ng "Redis not connected"
fi

if redis-cli -a "$REDIS_PASS" PUBSUB CHANNELS memory:updates >/dev/null 2>&1; then
  ok "Pub/sub channel ready"
else
  ng "Pub/sub channel not ready"
fi
echo ""

# Hooks
echo "Integration Hooks:"
[[ -x "$REPO/tools/mary_memory_hook.zsh" ]] && ok "Mary hook executable" || ng "Mary hook not executable"
[[ -x "$REPO/tools/rnd_memory_hook.zsh" ]] && ok "R&D hook executable" || ng "R&D hook not executable"
[[ -L "$REPO/tools/mary.zsh" ]] && ok "Mary alias exists" || ng "Mary alias missing"
[[ -L "$REPO/tools/rnd.zsh" ]] && ok "R&D alias exists" || ng "R&D alias missing"
echo ""

# Context file
echo "Shared Memory:"
[[ -f "$REPO/shared_memory/context.json" ]] && ok "context.json exists" || ng "context.json missing"
if [[ -f "$REPO/shared_memory/context.json" ]]; then
  jq . >/dev/null 2>&1 < "$REPO/shared_memory/context.json" && ok "context.json valid JSON" || ng "context.json invalid JSON"
fi
echo ""

# Recent activity (last 5 minutes)
echo "Recent Activity:"
if redis-cli -a "$REDIS_PASS" HGETALL memory:agents:mary >/dev/null 2>&1; then
  ok "Mary has activity"
else
  echo "ℹ️  Mary: no recent activity"
fi

if redis-cli -a "$REDIS_PASS" HGETALL memory:agents:rnd >/dev/null 2>&1; then
  ok "R&D has activity"
else
  echo "ℹ️  R&D: no recent activity"
fi
echo ""

# Health score
HEALTH_PCT=$(( SCORE * 100 / MAX_SCORE ))
echo "=== Health Score: $HEALTH_PCT% ($SCORE/$MAX_SCORE) ==="
echo ""

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "Issues found:"
  for err in "${errors[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "Quick fixes:"
  [[ " ${errors[@]} " =~ " LaunchAgent not loaded " ]] && echo "  - launchctl load ~/Library/LaunchAgents/com.02luka.memory.hub.plist"
  [[ " ${errors[@]} " =~ " Redis not connected " ]] && echo "  - Check Redis: redis-cli -a $REDIS_PASS PING"
  [[ " ${errors[@]} " =~ " Hub script missing " ]] && echo "  - Verify: ls -la $REPO/agents/memory_hub/memory_hub.py"
  exit 1
else
  echo "✅ All checks passed"
  exit 0
fi

# Claude Code health
echo "Claude Code:"
if [[ -f "$REPO/tools/claude_tools/metrics_collector.zsh" ]]; then
  ok "Metrics collector exists"
else
  ng "Metrics collector missing"
fi

# Check dependencies
if command -v shellcheck >/dev/null 2>&1; then
  ok "shellcheck available"
else
  ng "shellcheck missing"
fi

if command -v pylint >/dev/null 2>&1; then
  ok "pylint available"
else
  ng "pylint missing"
fi

if command -v jq >/dev/null 2>&1; then
  ok "jq available"
else
  ng "jq missing"
fi

# Check Redis metrics
if redis-cli -a "$REDIS_PASS" HGETALL memory:agents:claude >/dev/null 2>&1; then
  hook_rate=$(redis-cli -a "$REDIS_PASS" HGET memory:agents:claude hook_success_rate 2>/dev/null || echo "0")
  if [[ -n "$hook_rate" && $(echo "$hook_rate >= 80" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
    ok "Hook success rate acceptable (${hook_rate}%)"
  else
    echo "ℹ️  Hook success rate: ${hook_rate}%"
    MAX_SCORE=$((MAX_SCORE+1))
  fi
else
  echo "ℹ️  No Claude Code metrics in Redis yet"
  MAX_SCORE=$((MAX_SCORE+1))
fi
