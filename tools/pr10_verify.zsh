#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
REPORT_DIR="$BASE/g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests"

mkdir -p "$REPORT_DIR"

echo "✅ PR-10 CLS Auto-Approve Verification"
echo ""

############################
# Check if files were created
############################
TEMPLATE_FILE="$BASE/bridge/templates/pr10_auto_approve_email.html"
DOC_FILE="$BASE/bridge/docs/pr10_auto_approve_note.md"

CASE1_PASS=false
CASE2_PASS=false

if [ -f "$TEMPLATE_FILE" ]; then
    echo "✅ Case 1 PASS: Template file created"
    echo "   File: $TEMPLATE_FILE"
    echo "   Content preview:"
    head -3 "$TEMPLATE_FILE" | sed 's/^/      /'
    CASE1_PASS=true
else
    echo "❌ Case 1 FAIL: Template file not found"
    echo "   Expected: $TEMPLATE_FILE"
fi

echo ""

if [ -f "$DOC_FILE" ]; then
    echo "✅ Case 2 PASS: Doc file created"
    echo "   File: $DOC_FILE"
    echo "   Content preview:"
    head -3 "$DOC_FILE" | sed 's/^/      /'
    CASE2_PASS=true
else
    echo "❌ Case 2 FAIL: Doc file not found"
    echo "   Expected: $DOC_FILE"
fi

############################
# Check error inbox
############################
echo ""
echo "📋 Checking error inbox..."

ERROR_FILES=$(find "$BASE/bridge/error/MAIN" -name "WO-PR10-*" 2>/dev/null | wc -l | tr -d ' ')

if [ "$ERROR_FILES" -eq 0 ]; then
    echo "✅ No PR-10 WOs in error inbox (good)"
else
    echo "⚠️  Found $ERROR_FILES PR-10 WO(s) in error inbox:"
    find "$BASE/bridge/error/MAIN" -name "WO-PR10-*" 2>/dev/null | sed 's/^/   - /'
fi

############################
# Check telemetry
############################
echo ""
echo "📊 Checking telemetry..."

if [ -f "$BASE/g/telemetry/gateway_v3_router.log" ]; then
    PR10_ENTRIES=$(grep -c "WO-PR10" "$BASE/g/telemetry/gateway_v3_router.log" 2>/dev/null || echo "0")
    echo "   Found $PR10_ENTRIES PR-10 entries in telemetry"
    
    if [ "$PR10_ENTRIES" -gt 0 ]; then
        echo "   Recent entries:"
        grep "WO-PR10" "$BASE/g/telemetry/gateway_v3_router.log" | tail -2 | sed 's/^/      /'
    fi
else
    echo "⚠️  Telemetry log not found"
fi

############################
# Generate report
############################
REPORT_FILE="$REPORT_DIR/PR10_CLS_AUTO_APPROVE_VERIFICATION.md"

if [ "$CASE1_PASS" = true ] && [ "$CASE2_PASS" = true ]; then
    STATUS="PASS"
else
    STATUS="FAIL"
fi

cat > "$REPORT_FILE" <<EOF
# PR-10 CLS Auto-Approve Verification

**Date:** $(date -Iseconds)
**Status:** $STATUS

## Results

- **Case 1 (Templates):** $([ "$CASE1_PASS" = true ] && echo "✅ PASS" || echo "❌ FAIL")
  - File: \`$TEMPLATE_FILE\`
  - Exists: $([ -f "$TEMPLATE_FILE" ] && echo "Yes" || echo "No")

- **Case 2 (Docs):** $([ "$CASE2_PASS" = true ] && echo "✅ PASS" || echo "❌ FAIL")
  - File: \`$DOC_FILE\`
  - Exists: $([ -f "$DOC_FILE" ] && echo "Yes" || echo "No")

## Error Inbox

- PR-10 WOs in error: $ERROR_FILES

## Telemetry

- PR-10 entries: $PR10_ENTRIES

EOF

echo ""
echo "📄 Report saved: $REPORT_FILE"
echo ""
echo "PR-10 Status: $STATUS"

