#!/usr/bin/env zsh
# Monitor GitHub Actions runs and extract logs for failures
# Usage: tools/gh_watch_failures.zsh [workflow_name] [interval]

set -euo pipefail

WORKFLOW="${1:-}"
INTERVAL="${2:-5}"
LOG_DIR="${HOME}/02luka/g/reports/gh_failures"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 GitHub Actions Failure Monitor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Configuration:"
echo "   • Workflow: ${WORKFLOW:-all workflows}"
echo "   • Interval: ${INTERVAL}s"
echo "   • Log directory: $LOG_DIR"
echo ""
echo "💡 Press Ctrl+C to stop"
echo ""

# Track seen runs to avoid duplicate log extraction
SEEN_RUNS_FILE="${LOG_DIR}/.seen_runs"
touch "$SEEN_RUNS_FILE"

while true; do
  clear
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 Latest Runs ($(date '+%Y-%m-%d %H:%M:%S'))"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Get latest runs
  if [ -n "$WORKFLOW" ]; then
    RUNS=$(gh run list --workflow "$WORKFLOW" --limit 10 --json databaseId,displayTitle,status,conclusion,createdAt,workflowName,event 2>/dev/null || echo "[]")
  else
    RUNS=$(gh run list --limit 10 --json databaseId,displayTitle,status,conclusion,createdAt,workflowName,event 2>/dev/null || echo "[]")
  fi
  
  # Display runs
  echo "$RUNS" | jq -r '.[] | 
    "\(.databaseId) | \(.workflowName) | \(.event) | \(.status) | \(.conclusion // "in_progress") | \(.createdAt)"' | 
    column -t -s '|' || echo "No runs found"
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 Checking for failures..."
  echo ""
  
  # Check for failures and extract logs
  FAILED_RUNS=$(echo "$RUNS" | jq -r '.[] | select(.conclusion == "failure") | .databaseId')
  
  for RUN_ID in $FAILED_RUNS; do
    # Check if we've already processed this run
    if grep -q "^${RUN_ID}$" "$SEEN_RUNS_FILE" 2>/dev/null; then
      continue
    fi
    
    # Mark as seen
    echo "$RUN_ID" >> "$SEEN_RUNS_FILE"
    
    # Get run details
    RUN_INFO=$(echo "$RUNS" | jq -r ".[] | select(.databaseId == $RUN_ID) | \"\(.workflowName) | \(.displayTitle)\"")
    WORKFLOW_NAME=$(echo "$RUN_INFO" | cut -d'|' -f1 | xargs)
    TITLE=$(echo "$RUN_INFO" | cut -d'|' -f2 | xargs)
    
    echo "${RED}❌ FAILURE DETECTED${NC}"
    echo "   Run ID: $RUN_ID"
    echo "   Workflow: $WORKFLOW_NAME"
    echo "   Title: $TITLE"
    echo ""
    echo "${YELLOW}📥 Extracting logs...${NC}"
    
    # Create log file
    LOG_FILE="${LOG_DIR}/${RUN_ID}_${WORKFLOW_NAME//\//_}_$(date +%Y%m%d_%H%M%S).log"
    
    # Extract logs
    if gh run view "$RUN_ID" --log > "$LOG_FILE" 2>&1; then
      LOG_SIZE=$(du -h "$LOG_FILE" | cut -f1)
      echo "${GREEN}✅ Logs extracted: $LOG_FILE (${LOG_SIZE})${NC}"
      echo ""
      
      # Show error summary
      echo "${BLUE}📋 Error Summary:${NC}"
      grep -i "error\|failed\|failure" "$LOG_FILE" | head -10 | sed 's/^/   /'
      echo ""
    else
      echo "${RED}❌ Failed to extract logs${NC}"
      echo ""
    fi
  done
  
  if [ -z "$FAILED_RUNS" ]; then
    echo "${GREEN}✅ No new failures detected${NC}"
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⏳ Refreshing in ${INTERVAL}s... (Press Ctrl+C to stop)"
  sleep "$INTERVAL"
done
