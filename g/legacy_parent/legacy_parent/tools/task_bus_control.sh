#!/usr/bin/env bash
# Control script for task bus bridge
set -euo pipefail

SOT="${SOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PLIST_SRC="${SOT}/g/fixed_launchagents/com.02luka.task.bus.bridge.plist"
PLIST_DST="${HOME}/Library/LaunchAgents/com.02luka.task.bus.bridge.plist"
LABEL="com.02luka.task.bus.bridge"

case "${1:-}" in
  start)
    echo "Starting task bus bridge..."
    cp -a "$PLIST_SRC" "$PLIST_DST"
    launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$UID" "$PLIST_DST"
    launchctl enable "gui/$UID/$LABEL"
    sleep 2
    launchctl print "gui/$UID/$LABEL" 2>/dev/null | head -20 || echo "Failed to start"
    ;;
  stop)
    echo "Stopping task bus bridge..."
    launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
    rm -f "$PLIST_DST"
    pkill -f "task_bus_bridge.py" || true
    echo "✅ Stopped"
    ;;
  status)
    if launchctl print "gui/$UID/$LABEL" >/dev/null 2>&1; then
      echo "✅ Running"
      launchctl print "gui/$UID/$LABEL" | grep -E "state|pid"
    else
      echo "❌ Not running"
    fi
    ;;
  logs)
    tail -f "$HOME/Library/Logs/02luka/task_bus_bridge.log"
    ;;
  *)
    echo "Usage: $0 {start|stop|status|logs}"
    exit 1
    ;;
esac
