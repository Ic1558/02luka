#!/bin/bash
# macOS LaunchAgent Deployment Script
# Deploys com.02luka.digest LaunchAgent for daily digest generation

set -euo pipefail

echo "🚀 Deploying macOS LaunchAgent: com.02luka.digest"
echo ""

# Check if running on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "❌ This script is designed for macOS only"
    echo "   Current OS: $(uname -s)"
    exit 1
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAUNCHAGENT_SOURCE="${PROJECT_ROOT}/LaunchAgents/com.02luka.digest.plist"
LAUNCHAGENT_DEST="${HOME}/Library/LaunchAgents/com.02luka.digest.plist"

echo "📁 Project root: ${PROJECT_ROOT}"
echo "📄 Source plist: ${LAUNCHAGENT_SOURCE}"
echo "🎯 Destination: ${LAUNCHAGENT_DEST}"
echo ""

# Check if source plist exists
if [[ ! -f "${LAUNCHAGENT_SOURCE}" ]]; then
    echo "❌ Source plist not found: ${LAUNCHAGENT_SOURCE}"
    exit 1
fi

# Create LaunchAgents directory if it doesn't exist
echo "📁 Creating LaunchAgents directory..."
mkdir -p "${HOME}/Library/LaunchAgents"

# Stop existing LaunchAgent if running
echo "🛑 Stopping existing LaunchAgent..."
launchctl unload "${LAUNCHAGENT_DEST}" 2>/dev/null || true

# Copy plist file
echo "📋 Copying LaunchAgent plist..."
cp "${LAUNCHAGENT_SOURCE}" "${LAUNCHAGENT_DEST}"

# Set correct permissions
echo "🔐 Setting permissions..."
chmod 644 "${LAUNCHAGENT_DEST}"

# Load the LaunchAgent
echo "🔄 Loading LaunchAgent..."
launchctl load "${LAUNCHAGENT_DEST}"

# Verify deployment
echo "✅ Verifying deployment..."
if launchctl list | grep -q "com.02luka.digest"; then
    echo "✅ LaunchAgent loaded successfully"
    echo ""
    echo "📊 LaunchAgent Status:"
    launchctl list | grep "com.02luka.digest"
    echo ""
    echo "⏰ Schedule: Daily at 09:00"
    echo "📄 Script: ~/02luka/g/tools/services/daily_digest.cjs"
    echo "📝 Logs: ~/02luka/g/logs/digest.{out,err}"
    echo ""
    echo "🧪 Test commands:"
    echo "   launchctl start com.02luka.digest    # Manual run"
    echo "   launchctl list | grep com.02luka.digest  # Check status"
    echo "   tail -f ~/02luka/g/logs/digest.out   # Monitor logs"
else
    echo "❌ Failed to load LaunchAgent"
    exit 1
fi

echo ""
echo "🎉 macOS LaunchAgent deployment completed!"
