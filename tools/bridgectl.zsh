#!/bin/zsh

ROOT="/Users/icmini/02luka"
PLIST="$ROOT/infra/launchagents/com.02luka.gemini_bridge.plist"
SERVICE="com.02luka.gemini_bridge"
PY="$ROOT/gemini_venv/bin/python"
HEALTH="$ROOT/g/telemetry/bridge_health.json"
STDOUT_LOG="/tmp/com.02luka.gemini_bridge.stdout.log"
STDERR_LOG="/tmp/com.02luka.gemini_bridge.stderr.log"

health_field() {
  local key="$1"
  /usr/bin/python3 - "$HEALTH" "$key" 2>/dev/null <<'PY'
import json, sys, pathlib
path = sys.argv[1]
key = sys.argv[2]
p = pathlib.Path(path)
if not p.exists():
    sys.exit(1)
try:
    data = json.loads(p.read_text())
    val = data.get(key)
    if val is not None:
        print(val)
except Exception:
    sys.exit(1)
PY
}

job_pid() {
  launchctl print "gui/$(id -u)/$SERVICE" 2>/dev/null | awk '/pid =/{print $3; exit}'
}

pgrep_pid() {
  pgrep -f "gemini_bridge.py" 2>/dev/null | head -n 1
}

tail_logs() {
  echo "-- stdout (tail 80) --"
  [ -f "$STDOUT_LOG" ] && tail -n 80 "$STDOUT_LOG" || echo "missing $STDOUT_LOG"
  echo "-- stderr (tail 80) --"
  [ -f "$STDERR_LOG" ] && tail -n 80 "$STDERR_LOG" || echo "missing $STDERR_LOG"
}

case "$1" in
  start)
    launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    launchctl kickstart -k "gui/$(id -u)/$SERVICE" 2>/dev/null || true
    sleep 1
    for i in {1..5}; do
      JP=$(job_pid)
      PP=$(pgrep_pid)
      HP=$(health_field "pid")
      [ -n "$JP" ] && [ "$JP" = "$PP" ] && [ "$PP" = "$HP" ] && { echo "start ok (pid $PP)"; exit 0; }
      sleep 1
    done
    echo "start verification failed: launchctl pid=$(job_pid) pgrep pid=$(pgrep_pid) health pid=$(health_field "pid")"
    tail_logs
    exit 1
    ;;
  stop)
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    JP=$(job_pid)
    [ -n "$JP" ] && kill -TERM "$JP" 2>/dev/null || true
    for p in $(pgrep -f "gemini_bridge.py" 2>/dev/null); do
      kill -TERM "$p" 2>/dev/null || true
    done
    sleep 1
    for p in $(pgrep -f "gemini_bridge.py" 2>/dev/null); do
      kill -KILL "$p" 2>/dev/null || true
    done
    ;;
  status)
    echo "-- launchctl --"
    launchctl print "gui/$(id -u)/$SERVICE" 2>/dev/null | grep -E "state =|pid =" || echo "service not loaded"
    echo "-- pgrep --"
    pgrep -fl gemini_bridge.py 2>/dev/null || echo "no gemini_bridge.py processes"
    if [ -f "$HEALTH" ]; then
      HP=$(health_field "pid")
      HTS=$(health_field "ts")
      HOUT=$(health_field "last_output_file")
      MATCH="no"
      JP=$(job_pid)
      PP=$(pgrep_pid)
      [ -n "$HP" ] && [ "$HP" = "$JP" ] && [ "$HP" = "$PP" ] && MATCH="yes"
      echo "-- health -- pid=${HP:-missing} ts=${HTS:-missing} match=${MATCH} last_output=${HOUT:-none}"
    else
      echo "health file not found: $HEALTH"
    fi
    ;;
  verify)
    cd "$ROOT" || exit 1
    "$PY" gemini_bridge.py --self-check
    touch_file="$ROOT/magic_bridge/inbox/test_bridge_launchd_$(date +%s).md"
    echo "hi" > "$touch_file"
    out_file="${touch_file##*/}.summary.txt"
    for i in {1..30}; do
      if [ -f "$ROOT/magic_bridge/outbox/$out_file" ]; then
        echo "smoke ok: $out_file"
        break
      fi
      sleep 1
    done
    if [ ! -f "$ROOT/magic_bridge/outbox/$out_file" ]; then
      echo "smoke failed: no output $out_file"
      tail_logs
      exit 1
    fi
    # Self-enforcing Hygiene Guard: fail if operational queues are tracked in git
    tracked_noise=$(git ls-files "magic_bridge/inbox/" "magic_bridge/outbox/" "magic_bridge/processed/" 2>/dev/null | grep -v "\.gitkeep")
    if [ -n "$tracked_noise" ]; then
      echo "hygiene failed: tracked spool artifacts detected in git index:"
      echo "$tracked_noise"
      exit 1
    fi
    git status --porcelain 2>/dev/null | grep "^?? magic_bridge" && echo "git dirty for magic_bridge artifacts" && exit 1
    echo "verify complete"
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
