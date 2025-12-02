#!/usr/bin/env zsh
# Install MLS File Watcher as LaunchAgent

set -e

PROJECT_ROOT="${LAC_BASE_DIR:-$HOME/LocalProjects/02luka_local_g}"
PLIST_SRC="${PROJECT_ROOT}/LaunchAgents/com.02luka.mls_watcher.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.02luka.mls_watcher.plist"

echo "🔧 Installing MLS File Watcher..."

# Check dependencies
if ! command -v fswatch &> /dev/null; then
    echo "❌ Error: fswatch not installed"
    echo "   Install with: brew install fswatch"
    exit 1
fi

# Check script exists
if [[ ! -x "${PROJECT_ROOT}/g/tools/mls_file_watcher.zsh" ]]; then
    echo "❌ Error: mls_file_watcher.zsh not found or not executable"
    exit 1
fi

# Unload existing agent (if running)
if launchctl list | grep -q com.02luka.mls_watcher; then
    echo "⏸️  Unloading existing agent..."
    launchctl unload "$PLIST_DST" 2>/dev/null || true
fi

# Copy plist
echo "📋 Copying plist to ~/Library/LaunchAgents/..."
mkdir -p "$HOME/Library/LaunchAgents"
cp "$PLIST_SRC" "$PLIST_DST"

# Load agent
echo "🚀 Loading MLS File Watcher agent..."
launchctl load "$PLIST_DST"

# Wait 2 seconds for startup
sleep 2

# Verify it's running
if launchctl list | grep -q com.02luka.mls_watcher; then
    echo "✅ MLS File Watcher installed and running"
    echo ""
    echo "📊 Status:"
    launchctl list | grep com.02luka.mls_watcher | awk '{print "   PID: "$1", Status: "$2}'
    echo ""
    echo "📝 Logs:"
    echo "   Output: ${PROJECT_ROOT}/g/logs/mls_watcher.out.log"
    echo "   Errors: ${PROJECT_ROOT}/g/logs/mls_watcher.err.log"
    echo ""
    echo "🛑 To stop: launchctl unload ~/Library/LaunchAgents/com.02luka.mls_watcher.plist"
else
    echo "❌ Failed to start MLS File Watcher"
    echo "   Check logs: ${PROJECT_ROOT}/g/logs/mls_watcher.err.log"
    exit 1
fi
