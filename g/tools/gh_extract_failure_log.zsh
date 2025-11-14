#!/usr/bin/env zsh
# Extract logs from a specific failed run
# Usage: tools/gh_extract_failure_log.zsh <RUN_ID>

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <RUN_ID>"
  echo ""
  echo "Extract logs from a failed GitHub Actions run"
  echo ""
  echo "Examples:"
  echo "  $0 19255237532"
  echo "  $0 19255237532 --summary  # Show error summary only"
  exit 1
fi

RUN_ID="$1"
SHOW_SUMMARY="${2:-}"

LOG_DIR="${HOME}/02luka/g/reports/gh_failures"
mkdir -p "$LOG_DIR"

# Get run info
RUN_INFO=$(gh run view "$RUN_ID" --json databaseId,displayTitle,status,conclusion,createdAt,workflowName,event 2>/dev/null || {
  echo "❌ Failed to get run info for $RUN_ID"
  exit 1
})

WORKFLOW_NAME=$(echo "$RUN_INFO" | jq -r '.workflowName')
TITLE=$(echo "$RUN_INFO" | jq -r '.displayTitle')
STATUS=$(echo "$RUN_INFO" | jq -r '.status')
CONCLUSION=$(echo "$RUN_INFO" | jq -r '.conclusion // "unknown"')
CREATED=$(echo "$RUN_INFO" | jq -r '.createdAt')

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Run Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Run ID: $RUN_ID"
echo "   Workflow: $WORKFLOW_NAME"
echo "   Title: $TITLE"
echo "   Status: $STATUS"
echo "   Conclusion: $CONCLUSION"
echo "   Created: $CREATED"
echo ""

# Create log file
LOG_FILE="${LOG_DIR}/${RUN_ID}_${WORKFLOW_NAME//\//_}_$(date +%Y%m%d_%H%M%S).log"

echo "📥 Extracting logs..."
if gh run view "$RUN_ID" --log > "$LOG_FILE" 2>&1; then
  LOG_SIZE=$(du -h "$LOG_FILE" | cut -f1)
  echo "✅ Logs extracted: $LOG_FILE (${LOG_SIZE})"
  echo ""
  
  if [ "$SHOW_SUMMARY" = "--summary" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Error Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    grep -i "error\|failed\|failure" "$LOG_FILE" | head -20 | sed 's/^/   /'
    echo ""
  else
    echo "💡 To view error summary:"
    echo "   grep -i 'error\\|failed\\|failure' $LOG_FILE | head -20"
    echo ""
    echo "💡 To view full log:"
    echo "   less $LOG_FILE"
    echo "   # or"
    echo "   cat $LOG_FILE"
  fi
else
  echo "❌ Failed to extract logs"
  exit 1
fi
