#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# PR-11 Healthcheck Mode Switcher
# ═══════════════════════════════════════════════════════════════════════
# Switch between Day 0 (2x/day) and Day 2-7 (1x/day) modes
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

PLIST_FILE="${HOME}/Library/LaunchAgents/com.02luka.pr11.healthcheck.plist"

usage() {
    echo "Usage: $(basename "$0") <day0|day2-7>"
    echo ""
    echo "  day0     - Run every 12 hours (2x per day) - for first 24 hours"
    echo "  day2-7   - Run every 24 hours (1x per day) - after Day 0"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") day0      # Start Day 0 monitoring"
    echo "  $(basename "$0") day2-7     # Switch to Day 2-7 monitoring"
}

if [[ $# -ne 1 ]]; then
    usage
    exit 1
fi

MODE="$1"

case "$MODE" in
    day0)
        INTERVAL=43200  # 12 hours
        MODE_NAME="Day 0 (2x per day)"
        ;;
    day2-7)
        INTERVAL=86400  # 24 hours
        MODE_NAME="Day 2-7 (1x per day)"
        ;;
    *)
        echo "❌ Unknown mode: $MODE"
        usage
        exit 1
        ;;
esac

# Check if plist exists
if [[ ! -f "$PLIST_FILE" ]]; then
    echo "❌ LaunchAgent plist not found: $PLIST_FILE"
    exit 1
fi

# Unload if running
launchctl list | grep -q "com.02luka.pr11.healthcheck" && {
    echo "📤 Unloading existing LaunchAgent..."
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
}

# Update interval in plist
echo "⚙️  Updating interval to ${INTERVAL} seconds (${MODE_NAME})..."
/usr/libexec/PlistBuddy -c "Set :StartInterval $INTERVAL" "$PLIST_FILE" || {
    echo "❌ Failed to update plist"
    exit 1
}

# Reload LaunchAgent
echo "📥 Loading LaunchAgent..."
launchctl load "$PLIST_FILE" || {
    echo "❌ Failed to load LaunchAgent"
    exit 1
}

echo "✅ Switched to ${MODE_NAME}"
echo "   Interval: ${INTERVAL} seconds ($(($INTERVAL / 3600)) hours)"
echo "   Next run: ~$(($INTERVAL / 3600)) hours"
