#!/usr/bin/env bash
set -euo pipefail

# Install CLS LaunchAgent for macOS
# This script sets up automated CLS verification

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="com.02luka.cls.verification.plist"

echo "🧠 Installing CLS LaunchAgent..."

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCHAGENT_DIR"

# Copy plist file
cp "Library/LaunchAgents/$PLIST_FILE" "$LAUNCHAGENT_DIR/"

# Update paths in plist to use absolute paths
sed -i.bak "s|/workspaces/02luka-repo|$REPO_ROOT|g" "$LAUNCHAGENT_DIR/$PLIST_FILE"
rm "$LAUNCHAGENT_DIR/$PLIST_FILE.bak"

# Make verification script executable
chmod +x "$REPO_ROOT/scripts/cls_verification_with_upload.sh"

# Create necessary directories
mkdir -p "/Volumes/lukadata/CLS/tmp" "/Volumes/lukadata/CLS/logs" "/Volumes/lukadata/CLS/reports"
mkdir -p "/Volumes/hd2/CLS/tmp"

# Load the LaunchAgent
launchctl load "$LAUNCHAGENT_DIR/$PLIST_FILE" 2>/dev/null || true

echo "✅ CLS LaunchAgent installed successfully"
echo "📅 Scheduled to run daily at 09:00"
echo "📁 Reports will be uploaded to /Volumes/lukadata/CLS/reports/"
echo "📋 Logs available at /Volumes/lukadata/CLS/logs/"

# Show status
echo ""
echo "🔍 LaunchAgent Status:"
launchctl list | grep com.02luka.cls.verification || echo "   (Not yet loaded - will load on next login)"

echo ""
echo "🎯 To test manually:"
echo "   bash $REPO_ROOT/scripts/cls_verification_with_upload.sh"
