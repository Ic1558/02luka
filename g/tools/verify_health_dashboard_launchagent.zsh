#!/usr/bin/env zsh
# Verify Health Dashboard LaunchAgent
# Purpose: Check LaunchAgent status and recent dashboard updates

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
PLIST_DEST="$HOME/Library/LaunchAgents/com.02luka.health.dashboard.plist"
DASHBOARD_JSON="$REPO/g/reports/health_dashboard.json"
LOG_DIR="$REPO/logs"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

echo "=== Health Dashboard LaunchAgent Verification ==="
echo ""

# Check if plist exists
if [[ ! -f "$PLIST_DEST" ]]; then
  log "❌ LaunchAgent plist not found: $PLIST_DEST"
  exit 1
fi

# Check if LaunchAgent is loaded
log "🔍 Checking LaunchAgent status..."
LAUNCHCTL_OUTPUT=$(launchctl list 2>/dev/null | grep "com.02luka.health.dashboard" || true)
if [[ -n "$LAUNCHCTL_OUTPUT" ]]; then
  log "✅ LaunchAgent is loaded"
  log "   $LAUNCHCTL_OUTPUT"
else
  log "❌ LaunchAgent is not loaded"
  exit 1
fi

# Check dashboard file exists
log "📊 Checking dashboard file..."
if [[ ! -f "$DASHBOARD_JSON" ]]; then
  log "⚠️  Dashboard file not found: $DASHBOARD_JSON"
else
  # Check if JSON is valid
  if jq . "$DASHBOARD_JSON" >/dev/null 2>&1; then
    log "✅ Dashboard JSON is valid"
    
    # Check last update time
    if command -v jq >/dev/null 2>&1; then
      LAST_UPDATE=$(jq -r '.generated_at // "unknown"' "$DASHBOARD_JSON")
      log "📅 Last update: $LAST_UPDATE"
      
      # Check if update is recent (within last hour)
      if [[ "$LAST_UPDATE" != "unknown" ]]; then
        # Parse timestamp and compare
        UPDATE_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_UPDATE%.*}" +%s 2>/dev/null || \
                       date -d "${LAST_UPDATE%.*}" +%s 2>/dev/null || echo "0")
        NOW_EPOCH=$(date +%s)
        AGE=$((NOW_EPOCH - UPDATE_EPOCH))
        
        if [[ $AGE -lt 3600 ]]; then
          log "✅ Dashboard updated recently (${AGE}s ago)"
        else
          log "⚠️  Dashboard is stale (${AGE}s old, >1 hour)"
        fi
      fi
    fi
  else
    log "❌ Dashboard JSON is invalid"
    exit 1
  fi
fi

# Check log files
log "📝 Checking log files..."
if [[ -f "$LOG_DIR/health_dashboard.out.log" ]]; then
  OUT_SIZE=$(stat -f%z "$LOG_DIR/health_dashboard.out.log" 2>/dev/null || \
            stat -c%s "$LOG_DIR/health_dashboard.out.log" 2>/dev/null || echo "0")
  log "✅ stdout log exists (${OUT_SIZE} bytes)"
else
  log "⚠️  stdout log not found (may be normal if no executions yet)"
fi

if [[ -f "$LOG_DIR/health_dashboard.err.log" ]]; then
  ERR_SIZE=$(stat -f%z "$LOG_DIR/health_dashboard.err.log" 2>/dev/null || \
            stat -c%s "$LOG_DIR/health_dashboard.err.log" 2>/dev/null || echo "0")
  log "✅ stderr log exists (${ERR_SIZE} bytes)"
  
  # Check for recent errors
  if [[ $ERR_SIZE -gt 0 ]]; then
    ERR_COUNT=$(wc -l < "$LOG_DIR/health_dashboard.err.log" 2>/dev/null || echo "0")
    log "⚠️  Found $ERR_COUNT error lines in stderr log"
    if [[ $ERR_COUNT -gt 0 ]]; then
      log "📋 Last 3 error lines:"
      tail -3 "$LOG_DIR/health_dashboard.err.log" | sed 's/^/   /' || true
    fi
  fi
else
  log "ℹ️  stderr log not found (no errors yet)"
fi

echo ""
log "✅ Verification complete"
