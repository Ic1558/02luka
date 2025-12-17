#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
INBOX="$BASE/bridge/inbox/main"
TEST_FILE="$BASE/g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR9_ROLLBACK_TEST.md"

echo "🔄 PR-9 Rollback Execution"
echo ""

############################
# Step 3: Check file after modification
############################
echo "📊 Step 3: Checking file after modification..."

if [ ! -f "$TEST_FILE" ]; then
    echo "❌ File not found: $TEST_FILE"
    echo "   Make sure CLC has processed WO-PR9-ROLLBACK-TEST.yaml"
    exit 1
fi

echo "Current content:"
cat "$TEST_FILE"
echo ""

shasum -a 256 "$TEST_FILE" > "${TEST_FILE}.sha256.after_modify"
CHECKSUM_AFTER_MODIFY=$(cat "${TEST_FILE}.sha256.after_modify" | cut -d' ' -f1)
CHECKSUM_BEFORE=$(cat "${TEST_FILE}.sha256.before" | cut -d' ' -f1)

echo "Checksum (before):     $CHECKSUM_BEFORE"
echo "Checksum (after modify): $CHECKSUM_AFTER_MODIFY"

if [ "$CHECKSUM_BEFORE" = "$CHECKSUM_AFTER_MODIFY" ]; then
    echo "⚠️  WARNING: Checksums match - file was not modified!"
    echo "   CLC may not have processed the WO yet."
else
    echo "✅ File modified (GOOD → BROKEN state)"
fi

############################
# Step 4: Execute rollback
############################
echo ""
echo "🔄 Step 4: Executing rollback..."

# Option 1: Create rollback WO
cat > "$INBOX/WO-PR9-ROLLBACK-EXEC.yaml" <<'YAML'
wo_id: WO-PR9-ROLLBACK-EXEC
version: v1
source: pr9_rollback_exec
trigger: background
actor: CLC
strict_target: CLC

rollback:
  for_wo: "WO-PR9-ROLLBACK-TEST"
  strategy: git_revert
  reason: "PR-9 rollback drill execute"
YAML

echo "✅ Rollback WO created: WO-PR9-ROLLBACK-EXEC.yaml"
echo "   Waiting for CLC to process rollback..."
echo ""
echo "⏳ After rollback, run:"
echo "   zsh $BASE/tools/pr9_rollback_verify.zsh"

