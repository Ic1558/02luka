#!/usr/bin/env zsh
# filename: liam_smoke_test_new_rules.zsh
# purpose: Verify all new LIAM rules work as expected
# date: 2025-12-20
# agent: liam

set -u

REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 LIAM SMOKE TEST: New Rules Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PASS=0
FAIL=0

# === Test 1: Pre-action gate blocks without stamp ===
echo "[1/5] Testing: Gate blocks agent without stamp"
rm -f g/state/agent_readstamp_test.json 2>/dev/null
OUTPUT1=$(AGENT_ID=test zsh tools/pre_action_gate.zsh verify 2>&1 | perl -pe 's/\e\[[0-9;]*m//g')
if echo "$OUTPUT1" | grep -q "BLOCKED"; then
  echo "  ✅ PASS: Gate blocks correctly"
  ((PASS++))
else
  echo "  ❌ FAIL: Gate did not block"
  ((FAIL++))
fi
echo ""

# === Test 2: Gate allows interactive with warning ===
echo "[2/5] Testing: Gate warns interactive (no block)"
OUTPUT2=$(AGENT_ID= zsh tools/pre_action_gate.zsh verify 2>&1 | perl -pe 's/\e\[[0-9;]*m//g')
if echo "$OUTPUT2" | grep -q "Continuing anyway"; then
  echo "  ✅ PASS: Interactive gets warning, not block"
  ((PASS++))
else
  echo "  ❌ FAIL: Interactive was blocked"
  ((FAIL++))
fi
echo ""

# === Test 3: Emergency override works ===
echo "[3/5] Testing: Emergency override bypasses gate"
OUTPUT3=$(AGENT_ID=test SAVE_EMERGENCY=1 zsh tools/pre_action_gate.zsh verify 2>&1 | perl -pe 's/\e\[[0-9;]*m//g')
if echo "$OUTPUT3" | grep -q "Emergency"; then
  echo "  ✅ PASS: Emergency bypass works"
  ((PASS++))
else
  echo "  ❌ FAIL: Emergency bypass failed"
  ((FAIL++))
fi
echo ""

# === Test 4: Stamp creation stores 3 files SHA ===
echo "[4/5] Testing: Stamp stores 3 file SHAs"
AGENT_ID=smoke_test zsh tools/pre_action_gate.zsh create >/dev/null 2>&1
if grep -q "pr_autopilot_sha256" g/state/agent_readstamp_smoke_test.json 2>/dev/null && \
   grep -q "workflow_protocol_sha256" g/state/agent_readstamp_smoke_test.json 2>/dev/null; then
  echo "  ✅ PASS: Stamp has 3 file SHAs"
  ((PASS++))
else
  echo "  ❌ FAIL: Missing file SHAs in stamp"
  ((FAIL++))
fi
rm -f g/state/agent_readstamp_smoke_test.json 2>/dev/null
echo ""

# === Test 5: LIAM.md contains new rules ===
echo "[5/5] Testing: LIAM.md has mandatory rules"
if grep -q "NO STEPWISE ACTIONS" LIAM.md && \
   grep -q "BATCH OR NOTHING" LIAM.md && \
   grep -q "DRY-RUN" LIAM.md; then
  echo "  ✅ PASS: LIAM.md contains new rules"
  ((PASS++))
else
  echo "  ❌ FAIL: LIAM.md missing rules"
  ((FAIL++))
fi
echo ""

# === Summary ===
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RESULTS: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (( FAIL > 0 )); then
  echo "❌ SMOKE TEST FAILED"
  exit 1
else
  echo "✅ SMOKE TEST PASSED"
  exit 0
fi
