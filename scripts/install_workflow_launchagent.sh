#!/usr/bin/env bash
set -euo pipefail

# Install CLS Workflow LaunchAgent for macOS
# This script sets up automated workflow conflict scanning

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="com.02luka.cls.workflow.plist"

echo "🧠 Installing CLS Workflow LaunchAgent..."

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCHAGENT_DIR"

# Copy plist file
cp "Library/LaunchAgents/$PLIST_FILE" "$LAUNCHAGENT_DIR/"

# Update paths in plist to use absolute paths
sed -i.bak "s|/Users/icmini/dev/02luka-repo|$REPO_ROOT|g" "$LAUNCHAGENT_DIR/$PLIST_FILE"
rm "$LAUNCHAGENT_DIR/$PLIST_FILE.bak"

# Make workflow script executable
chmod +x "$REPO_ROOT/scripts/codex_workflow_assistant.sh"

# Create necessary directories
mkdir -p "/Volumes/lukadata/CLS/logs" "/Volumes/lukadata/CLS/reports"
mkdir -p "g/telemetry" "g/reports"

# Load the LaunchAgent
launchctl load "$LAUNCHAGENT_DIR/$PLIST_FILE" 2>/dev/null || true

echo "✅ CLS Workflow LaunchAgent installed successfully"
echo "📅 Scheduled to run daily at 10:00"
echo "📁 Reports will be generated in g/reports/"
echo "📋 Logs available at /Volumes/lukadata/CLS/logs/"

# Show status
echo ""
echo "🔍 Workflow LaunchAgent Status:"
launchctl list | grep com.02luka.cls.workflow || echo "   (Not yet loaded - will load on next login)"

echo ""
echo "🎯 To test manually:"
echo "   bash $REPO_ROOT/scripts/codex_workflow_assistant.sh --scan"
