#!/usr/bin/env zsh
# Control script for GitHub Actions Monitor Agent
# Usage: tools/gh_monitor_control.zsh [start|stop|restart|status|logs]

set -euo pipefail

PLIST_NAME="com.02luka.gh-monitor"
PLIST_FILE="${HOME}/Library/LaunchAgents/${PLIST_NAME}.plist"
AGENT_SCRIPT="${HOME}/02luka/tools/gh_monitor_agent.zsh"

case "${1:-}" in
  start)
    if [ -f "$PLIST_FILE" ]; then
      launchctl load "$PLIST_FILE" 2>/dev/null || launchctl load -w "$PLIST_FILE"
      echo "✅ GitHub Actions Monitor Agent started"
    else
      echo "❌ Plist file not found: $PLIST_FILE"
      echo "   Run: tools/setup_gh_monitor.zsh"
      exit 1
    fi
    ;;
    
  stop)
    if launchctl list "$PLIST_NAME" &>/dev/null; then
      launchctl unload "$PLIST_FILE" 2>/dev/null || true
      echo "✅ GitHub Actions Monitor Agent stopped"
    else
      echo "ℹ️  Agent is not running"
    fi
    ;;
    
  restart)
    "$0" stop
    sleep 1
    "$0" start
    ;;
    
  status)
    if launchctl list "$PLIST_NAME" &>/dev/null; then
      echo "✅ GitHub Actions Monitor Agent is running"
      echo ""
      echo "📋 Agent Info:"
      launchctl list "$PLIST_NAME" | grep -E "PID|LastExitStatus" || true
      echo ""
      echo "📁 Logs:"
      echo "   stdout: ~/02luka/logs/gh_monitor_agent.stdout.log"
      echo "   stderr: ~/02luka/logs/gh_monitor_agent.stderr.log"
      echo "   failures: ~/02luka/g/reports/gh_failures/"
    else
      echo "❌ GitHub Actions Monitor Agent is not running"
      echo ""
      echo "💡 To start: tools/gh_monitor_control.zsh start"
    fi
    ;;
    
  logs)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Agent Logs (last 50 lines)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [ -f "${HOME}/02luka/logs/gh_monitor_agent.stdout.log" ]; then
      tail -50 "${HOME}/02luka/logs/gh_monitor_agent.stdout.log"
    else
      echo "No log file found"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Error Logs (last 20 lines)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [ -f "${HOME}/02luka/logs/gh_monitor_agent.stderr.log" ]; then
      tail -20 "${HOME}/02luka/logs/gh_monitor_agent.stderr.log"
    else
      echo "No error log file found"
    fi
    ;;
    
  *)
    echo "Usage: $0 [start|stop|restart|status|logs]"
    echo ""
    echo "Commands:"
    echo "  start   - Start the monitoring agent"
    echo "  stop    - Stop the monitoring agent"
    echo "  restart - Restart the monitoring agent"
    echo "  status  - Check agent status"
    echo "  logs    - Show agent logs"
    echo ""
    echo "The agent will:"
    echo "  • Monitor GitHub Actions runs every 30 seconds"
    echo "  • Show macOS notifications when failures are detected"
    echo "  • Automatically extract logs for failed runs"
    echo "  • Run in background via LaunchAgent"
    exit 1
    ;;
esac
