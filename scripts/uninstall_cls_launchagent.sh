#!/usr/bin/env bash
set -euo pipefail

# Uninstall CLS LaunchAgent
# Removes the LaunchAgent and cleans up

PLIST_FILE="$HOME/Library/LaunchAgents/com.02luka.cls.verification.plist"

echo "🧠 Uninstalling CLS LaunchAgent..."

# Unload the service
if [[ -f "$PLIST_FILE" ]]; then
    echo "1) Unloading LaunchAgent..."
    launchctl bootout "gui/$UID" "$PLIST_FILE" 2>/dev/null || echo "   (Not loaded)"
    
    echo "2) Removing plist file..."
    rm -f "$PLIST_FILE"
    echo "✅ LaunchAgent uninstalled"
else
    echo "⚠️  LaunchAgent not found: $PLIST_FILE"
fi

# Optional: Clean up logs and reports
echo ""
echo "3) Cleaning up logs and reports..."
if [[ -d "/Volumes/lukadata/CLS/logs" ]]; then
    echo "   Logs directory: /Volumes/lukadata/CLS/logs/"
    echo "   (Logs preserved for debugging)"
fi

if [[ -d "/Volumes/lukadata/CLS/reports" ]]; then
    echo "   Reports directory: /Volumes/lukadata/CLS/reports/"
    echo "   (Reports preserved for history)"
fi

echo ""
echo "🎯 CLS LaunchAgent uninstalled successfully"
echo "   To reinstall: bash scripts/install_cls_launchagent.sh"
