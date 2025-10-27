#!/bin/bash
# Linux Simulation of macOS LaunchAgent Deployment
# Simulates the deployment process for testing

set -euo pipefail

echo "🧪 Simulating macOS LaunchAgent Deployment"
echo ""

# Check if running on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "❌ This simulation is designed for Linux only"
    echo "   Current OS: $(uname -s)"
    exit 1
fi

echo "📋 Simulation Environment:"
echo "   OS: $(uname -s)"
echo "   User: $(whoami)"
echo "   Home: $HOME"
echo "   Project: $(pwd)"
echo ""

# Simulate macOS paths
MACOS_HOME="/Users/$(whoami)"
MACOS_PROJECT="${MACOS_HOME}/02luka"
MACOS_LAUNCHAGENTS="${MACOS_HOME}/Library/LaunchAgents"
MACOS_PLIST="${MACOS_LAUNCHAGENTS}/com.02luka.digest.plist"

echo "🍎 Simulated macOS Environment:"
echo "   macOS Home: ${MACOS_HOME}"
echo "   macOS Project: ${MACOS_PROJECT}"
echo "   LaunchAgents: ${MACOS_LAUNCHAGENTS}"
echo "   Plist: ${MACOS_PLIST}"
echo ""

# Check source files
echo "📄 Checking source files..."
if [[ -f "LaunchAgents/com.02luka.digest.plist" ]]; then
    echo "✅ Source plist found"
else
    echo "❌ Source plist not found"
    exit 1
fi

if [[ -f "g/tools/services/daily_digest.cjs" ]]; then
    echo "✅ Daily digest script found"
else
    echo "❌ Daily digest script not found"
    exit 1
fi

# Simulate deployment steps
echo ""
echo "🚀 Simulating deployment steps..."
echo ""

echo "1️⃣ Creating LaunchAgents directory..."
echo "   mkdir -p ${MACOS_LAUNCHAGENTS}"
echo "   ✅ Directory would be created"

echo ""
echo "2️⃣ Stopping existing LaunchAgent..."
echo "   launchctl unload ${MACOS_PLIST} 2>/dev/null || true"
echo "   ✅ Existing LaunchAgent would be stopped"

echo ""
echo "3️⃣ Copying plist file..."
echo "   cp LaunchAgents/com.02luka.digest.plist ${MACOS_PLIST}"
echo "   ✅ Plist would be copied"

echo ""
echo "4️⃣ Setting permissions..."
echo "   chmod 644 ${MACOS_PLIST}"
echo "   ✅ Permissions would be set"

echo ""
echo "5️⃣ Loading LaunchAgent..."
echo "   launchctl load ${MACOS_PLIST}"
echo "   ✅ LaunchAgent would be loaded"

echo ""
echo "6️⃣ Verifying deployment..."
echo "   launchctl list | grep com.02luka.digest"
echo "   ✅ Status would be checked"

echo ""
echo "📊 LaunchAgent Configuration:"
echo "   Label: com.02luka.digest"
echo "   Schedule: Daily at 09:00"
echo "   Script: ~/02luka/g/tools/services/daily_digest.cjs --since 24h"
echo "   Logs: ~/02luka/g/logs/digest.{out,err}"
echo "   RunAtLoad: true"

echo ""
echo "🧪 Test Commands (for macOS):"
echo "   launchctl start com.02luka.digest"
echo "   launchctl list | grep com.02luka.digest"
echo "   tail -f ~/02luka/g/logs/digest.out"

echo ""
echo "🎉 Simulation completed successfully!"
echo "   Ready for actual macOS deployment"
