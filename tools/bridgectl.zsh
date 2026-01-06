#!/bin/zsh

ROOT="/Users/icmini/02luka"
PLIST="$ROOT/infra/launchagents/com.02luka.gemini_bridge.plist"
SERVICE="com.02luka.gemini_bridge"
PY="$ROOT/gemini_venv/bin/python"
HEALTH="$ROOT/g/telemetry/bridge_health.json"
REPORT_DIR="$ROOT/g/reports/ops"
REPORT_FILE="$REPORT_DIR/ops_status.md"
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
  ops-status)
    cd "$ROOT" || exit 1
    mkdir -p "$REPORT_DIR"
    VERIFY_MSG=$("$0" verify 2>&1)
    VERIFY_CODE=$?
    export VERIFY_MSG VERIFY_CODE
    GIT_STATE="CLEAN"
    if git status --porcelain | grep . >/dev/null; then
      GIT_STATE="DIRTY"
    fi
    export GIT_STATE
    /usr/bin/python3 - <<'PY'
import json, os, subprocess, statistics, pathlib
from datetime import datetime
from zoneinfo import ZoneInfo

ROOT = pathlib.Path("/Users/icmini/02luka")
HEALTH = ROOT / "g/telemetry/bridge_health.json"
TELEMETRY = ROOT / "g/telemetry/atg_runner.jsonl"
REPORT = ROOT / "g/reports/ops/ops_status.md"
INBOX = ROOT / "magic_bridge/inbox"
OUTBOX = ROOT / "magic_bridge/outbox"
MOCK = ROOT / "magic_bridge/mock_brain"
THRESHOLD = 200

verify_code = int(os.environ.get("VERIFY_CODE", "1"))
verify_msg = " ".join(os.environ.get("VERIFY_MSG", "").split())
git_state = os.environ.get("GIT_STATE", "UNKNOWN")

def load_health():
    if not HEALTH.exists():
        return None
    try:
        return json.loads(HEALTH.read_text())
    except Exception:
        return None

def parse_ts(ts):
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return None

def staleness_minutes(ts):
    dt = parse_ts(ts)
    if not dt:
        return None
    now = datetime.now(ZoneInfo("Asia/Bangkok"))
    return (now - dt).total_seconds() / 60.0

def uptime(pid):
    if not pid:
        return None
    try:
        out = subprocess.check_output(["ps", "-p", str(pid), "-o", "etime="], text=True).strip()
        return out or None
    except Exception:
        return None

def telemetry_stats():
    if not TELEMETRY.exists():
        return None
    try:
        lines = TELEMETRY.read_text().splitlines()[-2000:]
    except Exception:
        return None
    success = fail = 0
    durations = []
    for line in lines:
        try:
            rec = json.loads(line)
        except Exception:
            continue
        ev = rec.get("event")
        if ev == "processing_complete":
            success += 1
            if "duration_ms" in rec:
                try:
                    durations.append(float(rec["duration_ms"]))
                except Exception:
                    pass
        elif ev == "processing_failed":
            fail += 1
    def p95(vals):
        if not vals:
            return None
        vals = sorted(vals)
        idx = int(0.95 * (len(vals)-1))
        return vals[idx]
    return {
        "success": success,
        "fail": fail,
        "avg_ms": round(statistics.fmean(durations), 2) if durations else None,
        "p95_ms": round(p95(durations), 2) if durations else None,
    }

def spool_info(path):
    count = 0
    biggest = ("N/A", 0)
    if not path.exists():
        return {"path": str(path), "count": 0, "biggest": biggest}
    for entry in path.iterdir():
        if entry.name.startswith(".") or entry.name == ".gitkeep":
            continue
        if entry.is_file():
            count += 1
            sz = entry.stat().st_size
            if sz > biggest[1]:
                biggest = (entry.name, sz)
    return {"path": str(path), "count": count, "biggest": biggest}

health = load_health()
health_ts = health.get("ts") if health else None
pid = health.get("pid") if health else None
status = health.get("status") if health else "unknown"
last_error = health.get("error") if health else None
stale_min = staleness_minutes(health_ts) if health_ts else None
upt = uptime(pid)

tele = telemetry_stats()

spools = [
    ("inbox", spool_info(INBOX)),
    ("outbox", spool_info(OUTBOX)),
    ("mock_brain", spool_info(MOCK)),
]

overall = "✅"
notes = []
if not health:
    overall = "⚠️"
    notes.append("health missing")
elif stale_min is None or stale_min > 5:
    overall = "⚠️"
    notes.append("health stale")
if verify_code != 0 or git_state != "CLEAN":
    overall = "❌"
if any(s["count"] > THRESHOLD for _, s in spools):
    overall = "⚠️" if overall == "✅" else overall
    notes.append("spool high")

header_ts = datetime.now(ZoneInfo("Asia/Bangkok")).isoformat()

lines = []
lines.append(f"# Gemini Bridge Ops Status — {header_ts} — {overall}")
lines.append("")
lines.append("## Health")
lines.append(f"- Status: {status}")
lines.append(f"- PID: {pid or 'N/A'} (uptime: {upt or 'N/A'})")
if stale_min is not None:
    lines.append(f"- Last heartbeat: {health_ts} ({stale_min:.1f} min ago)")
else:
    lines.append(f"- Last heartbeat: N/A")
lines.append(f"- Last error: {last_error or 'None'}")

lines.append("")
lines.append("## Verification")
lines.append(f"- bridgectl verify: {'PASS' if verify_code==0 else 'FAIL'}")
lines.append(f"- git status: {git_state}")
if verify_msg:
    lines.append(f"- verify output: `{verify_msg.replace('`','\\`')}`")

lines.append("")
lines.append("## Telemetry (best-effort)")
if tele:
    lines.append(f"- Success: {tele['success']}  Fail: {tele['fail']}")
    lines.append(f"- Latency ms avg: {tele['avg_ms'] or 'N/A'}  p95: {tele['p95_ms'] or 'N/A'}")
else:
    lines.append("- N/A")

lines.append("")
lines.append("## Spool")
for name, info in spools:
    biggest_name, biggest_size = info["biggest"]
    warn = " ⚠️" if info["count"] > THRESHOLD else ""
    lines.append(f"- {name}: count={info['count']} biggest={biggest_name} ({biggest_size} bytes){warn}")

lines.append("")
lines.append("## Actions")
if overall == "✅":
    lines.append("- No action required.")
else:
    lines.append("1) Check running PID vs health and restart if needed: `./tools/bridgectl.zsh start`")
    lines.append("2) Inspect logs: tail /tmp/com.02luka.gemini_bridge.*.log")
    lines.append("3) Clear stuck spool files if count high (after backup).")

REPORT.write_text("\n".join(lines))
PY
    cat "$REPORT_FILE"
    ;;
  *)
    echo "Usage: $0 {start|stop|status|verify|ops-status}"
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
