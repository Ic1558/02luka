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

if [[ ! -f "$LOG_FILE" ]]; then
    echo "No log file found at $LOG_FILE"
    exit 1
fi

echo "📊 Codex Routing Metrics ($PERIOD)"
echo "=================================="
echo ""

# Total tasks
TOTAL=$(wc -l < "$LOG_FILE" | tr -d ' ')
echo "Total tasks logged: $TOTAL"

# By engine
echo ""
echo "By Engine:"
jq -r '.engine' "$LOG_FILE" | sort | uniq -c | awk '{printf "  %s: %d\n", $2, $1}'

# By task type
echo ""
echo "By Task Type:"
jq -r '.task_type' "$LOG_FILE" | sort | uniq -c | awk '{printf "  %s: %d\n", $2, $1}'

# Success rate
SUCCESS=$(jq -r 'select(.success==true)' "$LOG_FILE" | wc -l | tr -d ' ')
SUCCESS_RATE=$((SUCCESS * 100 / TOTAL))
echo ""
echo "Success Rate: $SUCCESS/$TOTAL ($SUCCESS_RATE%)"

# Average quality
AVG_QUALITY=$(jq -r 'select(.quality_score>0) | .quality_score' "$LOG_FILE" | awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "N/A"}')
echo "Average Quality: $AVG_QUALITY/10"

# CLC quota saved
SAVED=$(jq -r 'select(.clc_quota_saved==true and .engine=="codex")' "$LOG_FILE" | wc -l | tr -d ' ')
if [[ $TOTAL -gt 0 ]]; then
    SAVED_PCT=$((SAVED * 100 / TOTAL))
    echo ""
    echo "CLC Quota Savings:"
    echo "  Tasks routed to Codex: $SAVED"
    echo "  Estimated savings: ~$SAVED_PCT%"
fi

echo ""
echo "📈 Target Week 1: 40% savings, 95% success, 8/10 quality"
