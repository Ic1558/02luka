#!/usr/bin/env zsh
# Setup script for automated performance monitoring
# Installs LaunchAgent and validates setup

set -euo pipefail

LUKA_ROOT="${LUKA_ROOT:-$HOME/02luka}"
PLIST_SOURCE="${LUKA_ROOT}/Library/LaunchAgents/com.02luka.perf-collect-daily.plist"
PLIST_TARGET="$HOME/Library/LaunchAgents/com.02luka.perf-collect-daily.plist"
COLLECT_SCRIPT="${LUKA_ROOT}/tools/perf_collect_daily.zsh"
VALIDATE_SCRIPT="${LUKA_ROOT}/tools/perf_validate_3day.zsh"

echo "🔧 Setting up automated performance monitoring..."
echo ""

# Check scripts exist
if [[ ! -x "$COLLECT_SCRIPT" ]]; then
    echo "❌ Collection script not found or not executable: $COLLECT_SCRIPT"
    exit 1
fi

if [[ ! -x "$VALIDATE_SCRIPT" ]]; then
    echo "❌ Validation script not found or not executable: $VALIDATE_SCRIPT"
    exit 1
fi

# Check plist exists
if [[ ! -f "$PLIST_SOURCE" ]]; then
    echo "❌ LaunchAgent plist not found: $PLIST_SOURCE"
    exit 1
fi

# Create logs directory
mkdir -p "${LUKA_ROOT}/logs"

# Copy plist to LaunchAgents
echo "📋 Installing LaunchAgent..."
cp "$PLIST_SOURCE" "$PLIST_TARGET"

# Load LaunchAgent
echo "🔄 Loading LaunchAgent..."
launchctl unload "$PLIST_TARGET" 2>/dev/null || true
launchctl load "$PLIST_TARGET"

# Verify it's loaded
if launchctl list | grep -q "com.02luka.perf-collect-daily"; then
    echo "✅ LaunchAgent loaded successfully"
else
    echo "⚠️ LaunchAgent may not be loaded. Check with: launchctl list | grep perf-collect"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📅 Schedule:"
echo "   - Daily at 10:00 AM"
echo "   - Daily at 2:00 PM"
echo ""
echo "📝 Manual collection:"
echo "   $COLLECT_SCRIPT"
echo ""
echo "📊 Validation (after 3 days):"
echo "   $VALIDATE_SCRIPT"
echo ""
echo "📄 Logs:"
echo "   - Collection: ${LUKA_ROOT}/logs/perf_collect_daily.stdout.log"
echo "   - Errors: ${LUKA_ROOT}/logs/perf_collect_daily.stderr.log"
echo "   - Data: ${LUKA_ROOT}/g/logs/perf_observation_log.md"
echo ""
echo "🔍 Check status:"
echo "   launchctl list | grep perf-collect"
echo ""
echo "🛑 To stop:"
echo "   launchctl unload $PLIST_TARGET"
echo ""
echo "▶️ To restart:"
echo "   launchctl unload $PLIST_TARGET && launchctl load $PLIST_TARGET"
