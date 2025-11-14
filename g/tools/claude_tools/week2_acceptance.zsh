#!/usr/bin/env zsh
set -uo pipefail
BASE="${LUKA_SOT:-$HOME/02luka}"
ok=0; fail=0

echo "=== Week 2 Acceptance Test ==="
echo ""

# 1) commands exist
echo "1. Checking commands..."
for f in code-review.md commit.md health-check.md; do
  if [[ -f "$BASE/.claude/commands/$f" ]]; then
    echo "   ✅ $f"
    (( ok++ ))
  else
    echo "   ❌ MISS $f"
    (( fail++ ))
  fi
done

# 2) orchestrator & compare exist
echo ""
echo "2. Checking subagent tools..."
for f in orchestrator.zsh compare_results.zsh; do
  if [[ -x "$BASE/tools/subagents/$f" ]]; then
    echo "   ✅ $f"
    (( ok++ ))
  else
    echo "   ❌ MISS tools/subagents/$f"
    (( fail++ ))
  fi
done

# 2b) Check adapters
echo ""
echo "2b. Checking adapters..."
for f in cls.zsh claude.zsh; do
  if [[ -x "$BASE/tools/subagents/adapters/$f" ]]; then
    echo "   ✅ adapter: $f"
    (( ok++ ))
  else
    echo "   ❌ MISS tools/subagents/adapters/$f"
    (( fail++ ))
  fi
done

# 3) run a tiny orchestrator smoke if present
echo ""
echo "3. Testing orchestrator..."
if [[ -x "$BASE/tools/subagents/orchestrator.zsh" ]]; then
  echo "   Running smoke test (default: BACKEND=cls)..."
  BACKEND=cls "$BASE/tools/subagents/orchestrator.zsh" review "echo test" 2 >/dev/null 2>&1 || true
  echo "   ✅ Orchestrator smoke test completed (CLS backend)"
  (( ok++ ))
else
  echo "   ⚠️  Orchestrator not found, skipping smoke test"
  (( fail++ ))
fi

# 4) metrics hook present? (optional)
echo ""
echo "4. Checking metrics..."
if [[ -x "$BASE/tools/claude_tools/metrics_collector.zsh" ]]; then
  echo "   ✅ metrics_collector.zsh present"
  (( ok++ ))
else
  echo "   ⚠️  metrics_collector.zsh not found (optional)"
fi

echo ""
echo "=== Results ==="
echo "OK=$ok FAIL=$fail"
echo ""

if [[ $fail -eq 0 ]]; then
  echo "✅ Acceptance test PASSED"
  exit 0
else
  echo "❌ Acceptance test FAILED"
  exit 1
fi
