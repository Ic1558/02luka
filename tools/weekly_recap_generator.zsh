#!/usr/bin/env zsh
set -euo pipefail

# Weekly Recap Generator
# Purpose: Aggregate daily digests into weekly governance report
# Usage: ./weekly_recap_generator.zsh [YYYYMMDD]
#   - Without date: Uses current date (end of week)
#   - With date: Uses specified date as week end
# Schedule: Run weekly on Sunday 08:00 via LaunchAgent

REPO="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO"

# Determine week end date
if [[ -n "${1:-}" ]]; then
  WEEK_END="$1"
else
  WEEK_END=$(date +%Y%m%d)
fi

# Calculate week start (7 days ago)
if command -v gdate >/dev/null 2>&1; then
  WEEK_START=$(gdate -d "$WEEK_END -6 days" +%Y%m%d 2>/dev/null || date -v-6d -j -f %Y%m%d "$WEEK_END" +%Y%m%d)
else
  # macOS date fallback
  WEEK_START=$(date -v-6d -j -f %Y%m%d "$WEEK_END" +%Y%m%d 2>/dev/null || echo "")
fi

OUTPUT="g/reports/system/system_governance_WEEKLY_${WEEK_END}.md"

say() { print -r -- "$@"; }

say "=== Weekly Recap Generator ==="
say "Week: ${WEEK_START:-unknown} to $WEEK_END"
say "Output: $OUTPUT"
say ""

# Create output file
{
  echo "# Weekly Governance Report — Week Ending $WEEK_END"
  echo ""
  echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "**Week Range:** ${WEEK_START:-unknown} to $WEEK_END"
  echo ""
  echo "---"
  echo ""
  echo "## Executive Summary"
  echo ""
  
  # Count daily digests
  DIGEST_COUNT=0
  for f in g/reports/system/daily_digest_${WEEK_START:-*}*.md g/reports/system/daily_digest_${WEEK_END}*.md; do
    [[ -f "$f" ]] && ((DIGEST_COUNT++))
  done
  
  echo "- **Daily Digests:** $DIGEST_COUNT"
  echo "- **System Health:** See daily summaries below"
  echo "- **Key Events:** Aggregated from daily reports"
  echo ""
  echo "---"
  echo ""
  echo "## Daily Digest Summary"
  echo ""
  
  # Process each daily digest
  FOUND_ANY=0
  for f in g/reports/system/daily_digest_*.md; do
    [[ -f "$f" ]] || continue
    
    # Extract date from filename
    DATE_MATCH=$(basename "$f" | grep -oE '[0-9]{8}' || echo "")
    if [[ -z "$DATE_MATCH" ]]; then
      continue
    fi
    
    # Check if date is within week range
    if [[ -n "$WEEK_START" ]] && [[ "$DATE_MATCH" -lt "$WEEK_START" ]]; then
      continue
    fi
    if [[ "$DATE_MATCH" -gt "$WEEK_END" ]]; then
      continue
    fi
    
    FOUND_ANY=1
    echo "### $(basename "$f" .md)"
    echo ""
    echo "**Date:** $DATE_MATCH"
    echo ""
    
    # Extract key sections (headers and first paragraph)
    if grep -q "^## " "$f"; then
      echo "**Key Sections:**"
      grep "^## " "$f" | sed 's/^## /- /' | head -5
      echo ""
    fi
    
    # Extract summary if available
    if grep -q -i "summary\|executive\|overview" "$f"; then
      echo "**Summary:**"
      grep -A 3 -i "summary\|executive\|overview" "$f" | head -3 | sed 's/^/  /'
      echo ""
    fi
    
    echo "---"
    echo ""
  done
  
  if [[ $FOUND_ANY -eq 0 ]]; then
    echo "ℹ️  No daily digests found for this week."
    echo ""
  fi
  
  echo "## System Metrics"
  echo ""
  
  # Aggregate metrics from memory_metrics if available
  YEARMONTH=$(echo "$WEEK_END" | cut -c1-6)
  METRICS_FILE="g/reports/memory_metrics_${YEARMONTH}.json"
  if [[ -f "$METRICS_FILE" ]]; then
    echo "Monthly metrics available: \`$METRICS_FILE\`"
    echo ""
    # Extract key metrics if jq available
    if command -v jq >/dev/null 2>&1; then
      echo "**Agent Activity:**"
      jq -r '.agents // {} | to_entries[] | "  - \(.key): \(.value.total_tasks // 0) tasks"' "$METRICS_FILE" 2>/dev/null || echo "  (Unable to parse metrics)"
      echo ""
    fi
  else
    echo "ℹ️  Monthly metrics not yet available for this period."
    echo ""
  fi
  
  echo "## Recommendations"
  echo ""
  echo "Based on this week's activity:"
  echo "- Review daily digests for detailed information"
  echo "- Check system health reports for any issues"
  echo "- Monitor agent activity and performance"
  echo ""
  echo "---"
  echo ""
  echo "**Report Location:** \`$OUTPUT\`"
  echo "**Next Report:** $(date -v+7d -j -f %Y%m%d "$WEEK_END" +%Y%m%d 2>/dev/null || echo 'TBD')"
  
} > "$OUTPUT"

say "✅ Weekly recap generated: $OUTPUT"
say ""
say "Next steps:"
say "  1. Review: cat $OUTPUT"
say "  2. Commit: git add $OUTPUT && git commit -m 'docs: weekly governance recap $WEEK_END'"
say "  3. Push: git push origin main"
