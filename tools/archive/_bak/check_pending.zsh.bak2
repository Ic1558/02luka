#!/usr/bin/env zsh
# Check pending items from telemetry and work orders

set -uo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Pending Items Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PENDING_COUNT=0

echo "📋 Pending Work Orders"
echo "───────────────────────────────────────────────────────────────────"

# Check bridge/outbox for pending WOs
for dir in "$REPO_ROOT/bridge/outbox/CLC" "$REPO_ROOT/bridge/outbox/ENTRY" "$REPO_ROOT/bridge/error/MAIN"; do
    if [[ -d "$dir" ]]; then
        find "$dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.json" \) | while read -r wo_file; do
            if grep -q "status.*pending\|status: pending" "$wo_file" 2>/dev/null; then
                WO_ID=$(grep -E "^wo_id:|wo_id:" "$wo_file" 2>/dev/null | head -1 | sed 's/.*wo_id.*: *["'\'']*\([^"'\'']*\)["'\'']*/\1/')
                TITLE=$(grep -E "^title:|title:" "$wo_file" 2>/dev/null | head -1 | sed 's/.*title.*: *["'\'']*\([^"'\'']*\)["'\'']*/\1/')
                CREATED=$(grep -E "^created_at:|created_at:" "$wo_file" 2>/dev/null | head -1 | sed 's/.*created_at.*: *["'\'']*\([^"'\'']*\)["'\'']*/\1/')
                PRIORITY=$(grep -E "^priority:|priority:" "$wo_file" 2>/dev/null | head -1 | sed 's/.*priority.*: *["'\'']*\([^"'\'']*\)["'\'']*/\1/')
                
                echo "  • $WO_ID"
                echo "    Title: ${TITLE:-N/A}"
                echo "    Priority: ${PRIORITY:-N/A}"
                echo "    Created: ${CREATED:-N/A}"
                DIR_NAME=$(dirname "$wo_file")
                echo "    Location: $(basename "$DIR_NAME")/$(basename "$wo_file")"
                echo ""
                ((PENDING_COUNT++))
            fi
        done
    fi
done

# Check telemetry for pending status
echo "📊 Telemetry Pending Status"
echo "───────────────────────────────────────────────────────────────────"

if [[ -f "$REPO_ROOT/telemetry/cls_wo_cleanup.jsonl" ]]; then
    PENDING_TELEMETRY=$(jq -r 'select(.detail.status? == "pending" or .detail.status? == "PENDING") | "\(.ts) | \(.detail.wo_id) | \(.detail.status)"' "$REPO_ROOT/telemetry/cls_wo_cleanup.jsonl" 2>/dev/null | tail -5)
    if [[ -n "$PENDING_TELEMETRY" ]]; then
        echo "$PENDING_TELEMETRY"
    else
        echo "  No pending items in telemetry"
    fi
else
    echo "  Telemetry file not found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total Pending Work Orders: $PENDING_COUNT"
echo ""

if [[ $PENDING_COUNT -gt 0 ]]; then
    echo "⚠️  There are $PENDING_COUNT pending work order(s) waiting for processing"
    exit 1
else
    echo "✅ No pending work orders found"
    exit 0
fi
