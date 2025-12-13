#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
TEST_FILE="$BASE/g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR9_ROLLBACK_TEST.md"
REPORT_DIR="$BASE/g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests"

mkdir -p "$REPORT_DIR"

echo "✅ PR-9 Rollback Verification"
echo ""

############################
# Verify checksums
############################
if [ ! -f "${TEST_FILE}.sha256.before" ]; then
    echo "❌ Missing baseline checksum file"
    exit 1
fi

CHECKSUM_BEFORE=$(cat "${TEST_FILE}.sha256.before" | cut -d' ' -f1)

if [ -f "$TEST_FILE" ]; then
    shasum -a 256 "$TEST_FILE" > "${TEST_FILE}.sha256.after_rollback"
    CHECKSUM_AFTER_ROLLBACK=$(cat "${TEST_FILE}.sha256.after_rollback" | cut -d' ' -f1)
    
    echo "Checksum (before):        $CHECKSUM_BEFORE"
    echo "Checksum (after rollback): $CHECKSUM_AFTER_ROLLBACK"
    echo ""
    
    if [ "$CHECKSUM_BEFORE" = "$CHECKSUM_AFTER_ROLLBACK" ]; then
        echo "✅ PR-9 PASS: Checksums match - rollback successful!"
        ROLLBACK_STATUS="PASS"
    else
        echo "❌ PR-9 FAIL: Checksums do not match - rollback failed!"
        echo "   Before:  $CHECKSUM_BEFORE"
        echo "   After:   $CHECKSUM_AFTER_ROLLBACK"
        ROLLBACK_STATUS="FAIL"
    fi
else
    echo "⚠️  File not found after rollback (may have been deleted)"
    ROLLBACK_STATUS="UNKNOWN"
fi

############################
# Check audit logs
############################
echo ""
echo "📋 Checking audit logs..."

AUDIT_LOGS=$(find "$BASE/g/logs/clc_execution" -name "*PR9*" -o -name "*WO-PR9-*" 2>/dev/null | head -5)

if [ -n "$AUDIT_LOGS" ]; then
    echo "✅ Found audit logs:"
    for log in $AUDIT_LOGS; do
        echo "   - $log"
        if command -v python3 >/dev/null 2>&1; then
            echo "     Status: $(python3 -c "import sys, json; d=json.load(open('$log')); print(d.get('status', 'N/A'))" 2>/dev/null || echo "N/A")"
        fi
    done
else
    echo "⚠️  No audit logs found for PR-9"
fi

############################
# Generate report
############################
REPORT_FILE="$REPORT_DIR/PR9_ROLLBACK_VERIFICATION.md"

cat > "$REPORT_FILE" <<EOF
# PR-9 Rollback Test Verification

**Date:** $(date -Iseconds)
**Status:** $ROLLBACK_STATUS

## Checksums

- **Before:** \`$CHECKSUM_BEFORE\`
- **After Rollback:** \`${CHECKSUM_AFTER_ROLLBACK:-N/A}\`

## Result

$([ "$ROLLBACK_STATUS" = "PASS" ] && echo "✅ **PASS** - Rollback successful" || echo "❌ **FAIL** - Rollback failed or incomplete")

## Audit Logs

$(if [ -n "$AUDIT_LOGS" ]; then echo "Found:"; for log in $AUDIT_LOGS; do echo "- \`$log\`"; done; else echo "No audit logs found"; fi)

EOF

echo ""
echo "📄 Report saved: $REPORT_FILE"
echo ""
echo "PR-9 Status: $ROLLBACK_STATUS"

