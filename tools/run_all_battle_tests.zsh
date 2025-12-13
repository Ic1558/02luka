#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
REPORT_DIR="$BASE/g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests"

mkdir -p "$REPORT_DIR"

echo "🎯 Running All Battle Tests (PR-8, PR-9, PR-10)"
echo "================================================"
echo ""

############################
# PR-8: Error Scenarios
############################
echo "📋 PR-8: Error Scenarios"
echo "-----------------------"
zsh "$BASE/tools/pr8_v5_error_scenarios.zsh"
echo ""
echo "⏳ Waiting 5 seconds for gateway to process..."
sleep 5
echo ""

# Check results
echo "📊 PR-8 Results:"
tail -20 "$BASE/g/telemetry/gateway_v3_router.log" | grep -E "PR8|WO-PR8" || echo "   (No PR-8 entries yet - check again later)"
echo ""

############################
# PR-9: Rollback Test
############################
echo "📋 PR-9: Rollback Test"
echo "---------------------"
zsh "$BASE/tools/pr9_rollback_test.zsh"
echo ""
echo "⏳ Waiting 10 seconds for CLC to process..."
sleep 10
echo ""

zsh "$BASE/tools/pr9_rollback_execute.zsh"
echo ""
echo "⏳ Waiting 10 seconds for rollback..."
sleep 10
echo ""

zsh "$BASE/tools/pr9_rollback_verify.zsh"
echo ""

############################
# PR-10: CLS Auto-Approve
############################
echo "📋 PR-10: CLS Auto-Approve"
echo "------------------------"
zsh "$BASE/tools/pr10_cls_auto_approve.zsh"
echo ""
echo "⏳ Waiting 5 seconds for gateway to process..."
sleep 5
echo ""

zsh "$BASE/tools/pr10_verify.zsh"
echo ""

############################
# Summary
############################
echo "================================================"
echo "✅ All Battle Tests Completed"
echo ""
echo "📄 Reports saved in: $REPORT_DIR"
echo ""
echo "Next steps:"
echo "  1. Review reports in $REPORT_DIR"
echo "  2. Check telemetry: tail -40 $BASE/g/telemetry/gateway_v3_router.log"
echo "  3. Check monitor: zsh $BASE/tools/monitor_v5_production.zsh json"
echo ""

