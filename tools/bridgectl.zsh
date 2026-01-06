#!/bin/zsh

ROOT="/Users/icmini/02luka"
PLIST="$ROOT/infra/launchagents/com.02luka.gemini_bridge.plist"
SERVICE="com.02luka.gemini_bridge"
PY="$ROOT/gemini_venv/bin/python"
HEALTH="$ROOT/g/telemetry/bridge_health.json"

case "$1" in
  start)
    launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    launchctl kickstart -k "gui/$(id -u)/$SERVICE" 2>/dev/null || true
    ;;
  stop)
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    ;;
  status)
    launchctl print "gui/$(id -u)/$SERVICE" 2>/dev/null || echo "service not loaded"
    pgrep -fl gemini_bridge.py || echo "no gemini_bridge.py processes"
    if [ -f "$HEALTH" ]; then
      echo "-- health --"
      tail -n 5 "$HEALTH"
    else
      echo "health file not found: $HEALTH"
    fi
    ;;
  verify)
    cd "$ROOT" && "$PY" gemini_bridge.py --self-check
    ;;
  *)
    echo "Usage: $0 {start|stop|status|verify}"
    exit 1
    ;;
esac

# Verification commands (run from repo root):
#   ./gemini_venv/bin/python gemini_bridge.py --self-check
#   ./tools/bridgectl.zsh start
#   sleep 70 && tail g/telemetry/bridge_health.json
#   ./gemini_venv/bin/python gemini_bridge.py  # second instance should print 'Bridge already running'
#   touch magic_bridge/inbox/test_bridge_launchd.md
#   ls magic_bridge/outbox
#   git status --porcelain
