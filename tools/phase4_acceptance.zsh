#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
REDIS_PASS="changeme-02luka"
PASS=0
FAIL=0

ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

echo "=== Phase 4 Acceptance Tests ==="
echo ""

# Test 1: Hub running + LaunchAgent loaded
echo "Test 1: Hub Service"
if launchctl list | grep -q com.02luka.memory.hub; then
  ok "Hub LaunchAgent loaded"
else
  ng "Hub LaunchAgent not loaded"
fi

if [[ -f "$REPO/logs/memory_hub.out.log" ]]; then
  ok "Hub log exists"
else
  ng "Hub log missing"
fi
echo ""

# Test 2: Redis connectivity + pub/sub
echo "Test 2: Redis Connectivity"
if redis-cli -a "$REDIS_PASS" PING >/dev/null 2>&1; then
  ok "Redis responding"
else
  ng "Redis not responding"
fi

# Test pub/sub (non-blocking check)
if redis-cli -a "$REDIS_PASS" PUBSUB CHANNELS memory:updates >/dev/null 2>&1; then
  ok "Pub/sub channel exists"
else
  ng "Pub/sub channel check failed"
fi
echo ""

# Test 3: Mary hook → Redis + context.json
echo "Test 3: Mary Hook Integration"
TEST_ID="acceptance_$(date +%s)"
"$REPO/tools/mary_memory_hook.zsh" "$TEST_ID" "completed" '{"result":"success","test":true}' >/dev/null 2>&1

sleep 1

if redis-cli -a "$REDIS_PASS" HGETALL memory:agents:mary >/dev/null 2>&1; then
  ok "Mary data in Redis"
else
  ng "Mary data not in Redis"
fi

if jq -e '.agents.mary' "$REPO/shared_memory/context.json" >/dev/null 2>&1; then
  ok "Mary data in context.json"
else
  ng "Mary data not in context.json"
fi
echo ""

# Test 4: R&D hook → Redis + context.json
echo "Test 4: R&D Hook Integration"
"$REPO/tools/rnd_memory_hook.zsh" "RND-PR-ACPT" "processed" '{"score":88,"test":true}' >/dev/null 2>&1

sleep 1

if redis-cli -a "$REDIS_PASS" HGETALL memory:agents:rnd >/dev/null 2>&1; then
  ok "R&D data in Redis"
else
  ng "R&D data not in Redis"
fi

if jq -e '.agents.rnd' "$REPO/shared_memory/context.json" >/dev/null 2>&1; then
  ok "R&D data in context.json"
else
  ng "R&D data not in context.json"
fi
echo ""

# Test 5: Health check
echo "Test 5: Health Check"
if [[ -f "$REPO/tools/memory_hub_health.zsh" ]]; then
  if "$REPO/tools/memory_hub_health.zsh" >/dev/null 2>&1; then
    ok "Health check passes"
  else
    ng "Health check fails"
  fi
else
  ng "Health check script missing"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED - Phase 4 Operational"
  exit 0
else
  echo "❌ SOME TESTS FAILED - Review above"
  exit 1
fi
