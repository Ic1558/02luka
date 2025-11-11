#!/usr/bin/env zsh
# Setup script for GitHub Actions Monitor Agent
# Installs LaunchAgent and starts monitoring

set -euo pipefail

PLIST_NAME="com.02luka.gh-monitor"
PLIST_FILE="${HOME}/Library/LaunchAgents/${PLIST_NAME}.plist"
AGENT_SCRIPT="${HOME}/02luka/tools/gh_monitor_agent.zsh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Setting up GitHub Actions Monitor Agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if agent script exists
if [ ! -f "$AGENT_SCRIPT" ]; then
  echo "❌ Agent script not found: $AGENT_SCRIPT"
  exit 1
fi

# Stop existing agent if running
if launchctl list "$PLIST_NAME" &>/dev/null; then
  echo "⏹️  Stopping existing agent..."
  launchctl unload "$PLIST_FILE" 2>/dev/null || true
fi

# Copy plist file
echo "📋 Installing LaunchAgent plist..."
mkdir -p "${HOME}/Library/LaunchAgents"

# Check if plist already exists in LaunchAgents
if [ -f "${HOME}/Library/LaunchAgents/${PLIST_NAME}.plist" ]; then
  echo "ℹ️  Plist file already exists, using existing one"
else
  echo "   Creating plist file..."
  cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${AGENT_SCRIPT}</string>
        <string></string>
        <string>30</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${HOME}/02luka</string>
    <key>StandardOutPath</key>
    <string>${HOME}/02luka/logs/gh_monitor_agent.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/02luka/logs/gh_monitor_agent.stderr.log</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
</dict>
</plist>
EOF
fi

# Load the agent
echo "🚀 Starting agent..."
launchctl load -w "$PLIST_FILE"

# Wait a moment and check status
sleep 2

if launchctl list "$PLIST_NAME" &>/dev/null; then
  echo "✅ GitHub Actions Monitor Agent installed and started!"
  echo ""
  echo "📋 Agent Status:"
  launchctl list "$PLIST_NAME" | grep -E "PID|LastExitStatus" || true
  echo ""
  echo "💡 Control commands:"
  echo "   tools/gh_monitor_control.zsh status  # Check status"
  echo "   tools/gh_monitor_control.zsh stop    # Stop agent"
  echo "   tools/gh_monitor_control.zsh logs    # View logs"
  echo ""
  echo "📁 Logs:"
  echo "   ~/02luka/logs/gh_monitor_agent.stdout.log"
  echo "   ~/02luka/g/reports/gh_failures/"
else
  echo "❌ Failed to start agent"
  echo "   Check logs: ~/02luka/logs/gh_monitor_agent.stderr.log"
  exit 1
fi
