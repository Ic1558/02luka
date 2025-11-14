#!/usr/bin/env zsh
set -euo pipefail
HS_DIR="$HOME/02luka/monitoring"
PID="$HS_DIR/health_server.pid"
LOG="$HS_DIR/health_server.log"
APP="$HS_DIR/health_server.cjs"
case "${1:-status}" in
  status)
    if [[ -f "$PID" ]] && ps -p "$(cat "$PID")" >/dev/null 2>&1; then
      echo "✅ Health server running (PID $(cat "$PID"))"
    else
      echo "❌ Not running"
    fi ;;
  start)
    mkdir -p "$HS_DIR"
    nohup node "$APP" >"$LOG" 2>&1 & echo $! > "$PID"
    sleep 1
    echo "✅ Health server running on http://127.0.0.1:4000" ;;
  stop)
    [[ -f "$PID" ]] && kill "$(cat "$PID")" 2>/dev/null || true
    rm -f "$PID"; echo "✅ Stopped" ;;
  restart)
    $0 stop || true
    $0 start ;;
  *) echo "Usage: $0 {status|start|stop|restart}" && exit 1 ;;
esac
