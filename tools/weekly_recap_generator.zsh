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

# Set HTML_OUTPUT_DIR for index generator integration
HTML_OUTPUT_DIR="g/reports/system"

# Determine week end date
if [[ -n "${1:-}" ]]; then
  WEEK_END="$1"
else
  WEEK_END=$(date +%Y%m%d)
fi

# Calculate week start (7 days ago)
# Try macOS date first, then fallback
WEEK_START=$(date -v-6d -j -f %Y%m%d "$WEEK_END" +%Y%m%d 2>/dev/null || \
  date -d "$(echo "$WEEK_END" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/') -6 days" +%Y%m%d 2>/dev/null || \
  echo "")

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
  setopt null_glob
  for f in g/reports/system/daily_digest_*.md; do
    [[ -f "$f" ]] && ((DIGEST_COUNT++))
  done
  unsetopt null_glob
  
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
  # Use find to avoid glob expansion issues
  while IFS= read -r f; do
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
  done < <(find g/reports/system -maxdepth 1 -name "daily_digest_*.md" 2>/dev/null || true)
  
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
  
  echo "## Adaptive Insights Summary"
  echo ""
  
  # Aggregate adaptive insights from past week
  INSIGHTS_FOUND=0
  declare -a week_trends
  declare -a week_anomalies
  declare -a week_recommendations
  
  if command -v jq >/dev/null 2>&1 && [[ -d "mls/adaptive" ]]; then
    while IFS= read -r insight_file; do
      [[ -f "$insight_file" ]] || continue
      
      # Extract date from filename
      DATE_MATCH=$(basename "$insight_file" | grep -oE '[0-9]{8}' || echo "")
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
      
      INSIGHTS_FOUND=1
      
      # Extract trends
      trends=$(jq -r '.trends // {}' "$insight_file" 2>/dev/null || echo "{}")
      if [[ "$trends" != "{}" ]]; then
        echo "$trends" | jq -r 'to_entries[] | "\(.key): \(.value.direction) (\(.value.change))"' 2>/dev/null | while read trend_line; do
          week_trends+=("$trend_line")
        done
      fi
      
      # Extract anomalies
      anomalies=$(jq -r '.anomalies // []' "$insight_file" 2>/dev/null || echo "[]")
      if [[ "$anomalies" != "[]" ]]; then
        echo "$anomalies" | jq -r '.[] | "\(.metric): \(.severity) severity"' 2>/dev/null | while read anomaly_line; do
          week_anomalies+=("$anomaly_line")
        done
      fi
      
      # Extract recommendations
      recs=$(jq -r '.recommendations // []' "$insight_file" 2>/dev/null || echo "[]")
      if [[ "$recs" != "[]" ]]; then
        echo "$recs" | jq -r '.[]' 2>/dev/null | while read rec_line; do
          week_recommendations+=("$rec_line")
        done
      fi
    done < <(find mls/adaptive -maxdepth 1 -name "insights_*.json" 2>/dev/null || true)
  fi
  
  if [[ $INSIGHTS_FOUND -eq 0 ]]; then
    echo "ℹ️  No adaptive insights available for this week."
    echo ""
  else
    echo "### Trends (Last 7 Days)"
    echo ""
    if [[ ${#week_trends[@]} -gt 0 ]]; then
      printf '%s\n' "${week_trends[@]}" | sort -u | sed 's/^/- /'
    else
      echo "- No significant trends detected"
    fi
    echo ""
    
    echo "### Anomalies"
    echo ""
    if [[ ${#week_anomalies[@]} -gt 0 ]]; then
      printf '%s\n' "${week_anomalies[@]}" | sort -u | sed 's/^/- /'
    else
      echo "- No anomalies detected"
    fi
    echo ""
    
    echo "### Recommendations"
    echo ""
    if [[ ${#week_recommendations[@]} -gt 0 ]]; then
      printf '%s\n' "${week_recommendations[@]}" | sort -u | sed 's/^/- /'
    else
      echo "- No specific recommendations"
    fi
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

# Generate index and HTML snapshot (non-fatal)
if [[ -x "$REPO/tools/governance_index_generator.zsh" ]]; then
  say ""
  say "Generating governance index..."
  if "$REPO/tools/governance_index_generator.zsh" "$WEEK_END" 2>&1; then
    say "✅ Index and snapshot generated"
    
    # Add link to HTML snapshot if it exists
    HTML_SNAPSHOT="$REPO/$HTML_OUTPUT_DIR/trends_snapshot_${WEEK_END}.html"
    if [[ -f "$HTML_SNAPSHOT" ]]; then
      # Insert link after "Adaptive Insights Summary" section
      if grep -q "## Adaptive Insights Summary" "$OUTPUT"; then
        # Find line number of "## Recommendations" (after Adaptive Insights)
        rec_line=$(grep -n "^## Recommendations" "$OUTPUT" | cut -d: -f1 || echo "")
        if [[ -n "$rec_line" ]]; then
          # Insert link before Recommendations section
          sed -i.bak "${rec_line}i\\
\\
## Trend Visualization\\
\\
[View Trends Snapshot](trends_snapshot_${WEEK_END}.html)\\
\\
" "$OUTPUT"
          rm -f "$OUTPUT.bak"
        fi
      fi
    fi
  else
    say "⚠️  Index generation failed (non-fatal)"
  fi
else
  say "ℹ️  Index generator not found (skipping)"
fi

say ""
say "Next steps:"
say "  1. Review: cat $OUTPUT"
say "  2. Commit: git add $OUTPUT && git commit -m 'docs: weekly governance recap $WEEK_END'"
say "  3. Push: git push origin main"
