#!/usr/bin/env bash
set -euo pipefail

# Check OPS-Atomic Monitor Status
# Shows current state, recent logs, and latest reports

REPO_ROOT="/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"
LABEL="com.02luka.ops_atomic_monitor"
LOG_FILE="${REPO_ROOT}/g/logs/ops_monitor.log"
ERR_FILE="${REPO_ROOT}/g/logs/ops_monitor.err"
REPORTS_DIR="${REPO_ROOT}/g/reports/ops_atomic"

echo "📊 OPS-Atomic Monitor Status"
echo "======================================"
echo ""

# Check if loaded
if launchctl list | grep -q "$LABEL"; then
  echo "✅ Status: RUNNING"
  echo ""
  echo "📋 LaunchAgent Info:"
  launchctl list | grep "$LABEL" | awk '{print "   PID: " $1 "\n   Exit Code: " $2 "\n   Label: " $3}'
else
  echo "⏸️  Status: NOT RUNNING"
fi

echo ""
echo "======================================"
echo ""

# Check if plist exists
PLIST_DST="${HOME}/Library/LaunchAgents/com.02luka.ops_atomic_monitor.plist"
if [ -f "$PLIST_DST" ]; then
  echo "📦 LaunchAgent File: EXISTS"
  echo "   Path: $PLIST_DST"
else
  echo "📦 LaunchAgent File: NOT DEPLOYED"
fi

echo ""
echo "======================================"
echo ""

# Show recent logs
if [ -f "$LOG_FILE" ]; then
  LOG_SIZE=$(wc -l < "$LOG_FILE")
  echo "📝 Recent Logs (last 10 lines of $LOG_SIZE total):"
  tail -10 "$LOG_FILE" | sed 's/^/   /'
else
  echo "📝 Logs: No log file found"
fi

echo ""
echo "======================================"
echo ""

# Show recent errors
if [ -f "$ERR_FILE" ] && [ -s "$ERR_FILE" ]; then
  ERR_SIZE=$(wc -l < "$ERR_FILE")
  echo "⚠️  Recent Errors (last 10 lines of $ERR_SIZE total):"
  tail -10 "$ERR_FILE" | sed 's/^/   /'
else
  echo "✅ Errors: No errors logged"
fi

echo ""
echo "======================================"
echo ""

# Show latest reports
if [ -d "$REPORTS_DIR" ] && [ "$(ls -A "$REPORTS_DIR" 2>/dev/null)" ]; then
  REPORT_COUNT=$(ls -1 "$REPORTS_DIR" | wc -l)
  echo "📊 Latest Reports (showing 5 most recent of $REPORT_COUNT total):"
  ls -lt "$REPORTS_DIR" | head -6 | tail -5 | awk '{printf "   %s %s %2s %s %s\n", $6, $7, $8, $9, $10}'
  echo ""
  echo "   Latest report:"
  LATEST_REPORT=$(ls -t "$REPORTS_DIR" | head -1)
  if [ -n "$LATEST_REPORT" ]; then
    echo "   📄 ${LATEST_REPORT}"
    # Show first few lines of latest report
    head -15 "${REPORTS_DIR}/${LATEST_REPORT}" | sed 's/^/      /'
  fi
else
  echo "📊 Reports: No reports generated yet"
fi

echo ""
echo "======================================"
echo ""

# Show manual trigger command
echo "💡 Manual Commands:"
echo "   Enable:  bash scripts/ops_monitor/enable_ops_monitor.sh"
echo "   Disable: bash scripts/ops_monitor/disable_ops_monitor.sh"
echo "   Test:    node run/ops_atomic_monitor.cjs"
