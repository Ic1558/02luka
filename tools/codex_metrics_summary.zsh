#!/usr/bin/env zsh
# ======================================================================
# Codex Metrics Summary
# Purpose: Analyze codex_routing_log.jsonl and show metrics
# Usage: zsh ~/02luka/tools/codex_metrics_summary.zsh [period]
#        zsh ~/02luka/tools/codex_metrics_summary.zsh week
#        zsh ~/02luka/tools/codex_metrics_summary.zsh all
# ======================================================================

set -euo pipefail

LOG_FILE="${HOME}/02luka/g/reports/codex_routing_log.jsonl"
PERIOD="${1:-week}"

warn() {
    echo "⚠️  $*" >&2
}

if [[ ! -f "$LOG_FILE" ]]; then
    echo "No log file found at $LOG_FILE"
    exit 1
fi

VALID_LOG_FILE="$(mktemp -t codex_routing_log.valid.XXXXXX)"
trap 'rm -f "$VALID_LOG_FILE"' EXIT

INVALID_COUNT=0
LINE_NO=0
while IFS= read -r line || [[ -n "$line" ]]; do
    LINE_NO=$((LINE_NO + 1))
    line_trim="${line#"${line%%[![:space:]]*}"}"
    if [[ -z "$line_trim" ]]; then
        continue
    fi
    if [[ "$line_trim" == \#* ]]; then
        continue
    fi
    if echo "$line" | jq -e . >/dev/null 2>&1; then
        echo "$line" >> "$VALID_LOG_FILE"
    else
        INVALID_COUNT=$((INVALID_COUNT + 1))
        warn "Skipping invalid JSON at line $LINE_NO"
    fi
done < "$LOG_FILE"

LOG_SOURCE="$VALID_LOG_FILE"
if [[ $INVALID_COUNT -gt 0 ]]; then
    warn "Skipped $INVALID_COUNT invalid JSON line(s)"
fi

echo "📊 Codex Routing Metrics ($PERIOD)"
echo "=================================="
echo ""

# Total tasks
TOTAL=$(wc -l < "$LOG_SOURCE" | tr -d ' ')
echo "Total tasks logged: $TOTAL"

# By engine
echo ""
echo "By Engine:"
jq -r '.engine' "$LOG_SOURCE" | sort | uniq -c | awk '{printf "  %s: %d\n", $2, $1}'

# By task type
echo ""
echo "By Task Type:"
jq -r '.task_type' "$LOG_SOURCE" | sort | uniq -c | awk '{printf "  %s: %d\n", $2, $1}'

# Success rate
echo ""
if [[ $TOTAL -gt 0 ]]; then
    SUCCESS=$(jq -c 'select(.success==true)' "$LOG_SOURCE" | wc -l | tr -d ' ')
    SUCCESS_RATE=$((SUCCESS * 100 / TOTAL))
    echo "Success Rate: $SUCCESS/$TOTAL ($SUCCESS_RATE%)"
else
    echo "Success Rate: 0/0 (N/A)"
fi

# Average quality
AVG_QUALITY=$(jq -r 'select(.quality_score>0) | .quality_score' "$LOG_SOURCE" | awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "N/A"}')
echo "Average Quality: $AVG_QUALITY/10"

# CLC quota saved
SAVED=$(jq -c 'select(.clc_quota_saved==true and .engine=="codex")' "$LOG_SOURCE" | wc -l | tr -d ' ')
if [[ $TOTAL -gt 0 ]]; then
    SAVED_PCT=$((SAVED * 100 / TOTAL))
    echo ""
    echo "CLC Quota Savings:"
    echo "  Tasks routed to Codex: $SAVED"
    echo "  Estimated savings: ~$SAVED_PCT%"
fi

echo ""
echo "📈 Target Week 1: 40% savings, 95% success, 8/10 quality"
