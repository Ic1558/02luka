#!/usr/bin/env zsh
set -euo pipefail
# Adjusted path for workspace context
cd "$(dirname "$0")/.." 

echo "== GIT STATUS (must be intentional before commit) =="
git status --porcelain=v1 || true
echo

echo "== RUNNING PIDS =="
pgrep -fl "bridge.sh|gemini_bridge.py|fs_watcher.py" || true
echo

echo "== Telemetry rate check (last 60s) =="
python3 - <<'PY'
import json, time
from datetime import datetime, timedelta, timezone
path="g/telemetry/atg_runner.jsonl"
# Local time is UTC+7
cut = datetime.now(timezone(timedelta(hours=7))) - timedelta(seconds=60)
cnt=0
last=[]
try:
    with open(path,"r",encoding="utf-8") as f:
        for line in f:
            line=line.strip()
            if not line: continue
            try:
                o=json.loads(line)
            except: 
                continue
            ts=o.get("ts","")
            try:
                # parse like 2026-01-03T02:02:39.881418+07:00
                t=datetime.fromisoformat(ts)
            except:
                continue
            if t >= cut:
                cnt += 1
                last.append(o.get("event"))
except FileNotFoundError:
    print("(no atg_runner.jsonl)")
    raise SystemExit(0)

print("events_last_60s =", cnt)
if cnt:
    print("tail_events =", last[-10:])
PY
echo

echo "== Bridge stdout tail (look for repeated 'Detected change') =="
tail -n 40 /tmp/com.antigravity.bridge.stdout.log 2>/dev/null || echo "(no bridge stdout)"
echo

echo "== Bridge stderr tail (deprecation spam?) =="
tail -n 10 /tmp/com.antigravity.bridge.stderr.log 2>/dev/null || echo "(no bridge stderr)"
