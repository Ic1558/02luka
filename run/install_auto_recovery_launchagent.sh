#!/usr/bin/env bash
# Install Auto-Recovery LaunchAgent for 02LUKA
# Creates self-healing macOS node with automatic health checks

set -euo pipefail

echo "🔧 Installing 02LUKA Auto-Recovery LaunchAgent..."

# Create logs directory
mkdir -p ~/Library/Logs/02luka

# Copy LaunchAgent plist
cp /tmp/com.02luka.auto-recovery.plist ~/Library/LaunchAgents/

# Set permissions
chmod 644 ~/Library/LaunchAgents/com.02luka.auto-recovery.plist

# Load the service
launchctl load ~/Library/LaunchAgents/com.02luka.auto-recovery.plist

echo "✅ Auto-Recovery LaunchAgent installed and loaded"
echo "📊 Service will run:"
echo "   - At boot (RunAtLoad: true)"
echo "   - Every hour (StartInterval: 3600)"
echo "   - Logs: ~/Library/Logs/02luka/auto_recovery.log"
echo "   - Out/Err: ~/Library/Logs/02luka/com.02luka.auto-recovery.{out,err}"

# Test the service
echo "🧪 Testing service..."
launchctl list | grep com.02luka.auto-recovery || echo "Service not found in list"

echo "🎯 02LUKA is now a Self-Healing Node!"
