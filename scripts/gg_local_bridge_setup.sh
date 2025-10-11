#!/usr/bin/env bash

set -euo pipefail

# ============================================================================
# GG Local Bridge bootstrap script
# ----------------------------------------------------------------------------
# This script prepares the "gg_local_bridge" worker that orchestrates tasks
# coming from Redis queues.  It mirrors the manual steps that were previously
# documented in shared notes so the process can be reproduced quickly on new
# machines.
#
# The defaults match the 02luka developer environment but everything is
# customisable via the variables below before invoking the script.
# ============================================================================

SOT="${SOT:-$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka}"
REPO="${REPO:-$HOME/dev/02luka-repo}"
AGENT_DIR="${AGENT_DIR:-$SOT/agents/gg_local_bridge}"
LOGDIR="${LOGDIR:-$HOME/Library/Logs/02luka/gg_bridge}"
PLIST="${PLIST:-$HOME/Library/LaunchAgents/com.02luka.gg_local_bridge.plist}"
ENV_FILE="${ENV:-$AGENT_DIR/.env}"

PYTHON="${PY:-$AGENT_DIR/venv/bin/python}"

mkdir -p "$AGENT_DIR" "$LOGDIR"

if [ ! -d "$AGENT_DIR/venv" ]; then
  /usr/bin/python3 -m venv "$AGENT_DIR/venv"
fi

"$AGENT_DIR/venv/bin/pip" install --upgrade pip >/dev/null
"$AGENT_DIR/venv/bin/pip" install redis pyyaml watchdog >/dev/null

cat > "$ENV_FILE" <<'ENV'
REDIS_URL=redis://127.0.0.1:6379/0
REQUEST_QUEUE=gg:requests
RESULT_QUEUE=gg:results

ALLOW_PATH_1=$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka
ALLOW_PATH_2=$HOME/dev/02luka-repo
ENV

cat > "$AGENT_DIR/gg_orchestrator.py" <<'PY'
import os, sys, json, time, subprocess, traceback
from pathlib import Path
from datetime import datetime
import redis


def env(key, default=None):
    value = os.environ.get(key)
    return value if value not in (None, "") else default


REDIS_URL = env("REDIS_URL", "redis://127.0.0.1:6379/0")
REQUEST_QUEUE = env("REQUEST_QUEUE", "gg:requests")
RESULT_QUEUE = env("RESULT_QUEUE", "gg:results")

ALLOW = []
for key in ("ALLOW_PATH_1", "ALLOW_PATH_2", "ALLOW_PATH_3"):
    raw = env(key, "")
    path = os.path.expanduser(raw) if raw else ""
    if path:
        ALLOW.append(str(Path(path).resolve()))

LOGDIR = Path(os.path.expanduser("~/Library/Logs/02luka/gg_bridge"))
LOGDIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOGDIR / "gg_orchestrator.log"


def log(message: str) -> None:
    line = f"[{datetime.now().isoformat(timespec='seconds')}] {message}"
    print(line, flush=True)
    content = ""
    if LOG_FILE.exists():
        content = LOG_FILE.read_text()
    LOG_FILE.write_text(content + line + "\n")


def in_safelist(path: Path) -> bool:
    resolved = str(path.resolve())
    return any(resolved.startswith(safe) for safe in ALLOW)


def write_result(conn, run_id, status, payload):
    conn.lpush(
        RESULT_QUEUE,
        json.dumps({
            "run_id": run_id,
            "ts": datetime.now().isoformat(),
            "status": status,
            **payload,
        }),
    )


def action_create_file(task):
    path = Path(os.path.expanduser(task["path"]))
    content = task.get("content", "")
    if not in_safelist(path):
        return "denied", {"error": "path_not_allowed", "path": str(path)}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    return "ok", {"path": str(path), "bytes": len(content)}


def action_run_shell(task):
    cmd = task["cmd"]
    cwd = Path(os.path.expanduser(task.get("cwd", "~"))).expanduser()
    if not in_safelist(cwd):
        return "denied", {"error": "cwd_not_allowed", "cwd": str(cwd)}
    proc = subprocess.run(
        cmd,
        cwd=str(cwd),
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return (
        "ok" if proc.returncode == 0 else "fail",
        {
            "code": proc.returncode,
            "stdout": proc.stdout[-4000:],
            "stderr": proc.stderr[-4000:],
        },
    )


def action_apply_patch(task):
    cwd = Path(os.path.expanduser(task.get("cwd", "~"))).expanduser()
    if not in_safelist(cwd):
        return "denied", {"error": "cwd_not_allowed", "cwd": str(cwd)}
    patch = task["patch"]
    try:
        check = subprocess.Popen(
            "git apply --check -",
            cwd=str(cwd),
            shell=True,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        _, check_err = check.communicate(patch)
        if check.returncode != 0:
            return "fail", {"phase": "check", "stderr": check_err[-4000:]}

        apply = subprocess.Popen(
            "git apply -",
            cwd=str(cwd),
            shell=True,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        _, apply_err = apply.communicate(patch)
        if apply.returncode != 0:
            return "fail", {"phase": "apply", "stderr": apply_err[-4000:]}

        return "ok", {"cwd": str(cwd)}
    except Exception as exc:  # pragma: no cover - defensive
        return "fail", {"error": str(exc), "trace": traceback.format_exc()}


def handle_task(conn, task):
    run_id = task.get("run_id") or f"rid-{int(time.time())}"
    action = task.get("action")
    try:
        if action == "create_file":
            status, payload = action_create_file(task)
        elif action == "run_shell":
            status, payload = action_run_shell(task)
        elif action == "apply_patch":
            status, payload = action_apply_patch(task)
        else:
            status, payload = "fail", {"error": "unknown_action", "action": action}
    except Exception as exc:  # pragma: no cover - defensive
        status, payload = "fail", {"exception": str(exc), "trace": traceback.format_exc()}
    write_result(conn, run_id, status, payload)


def main():
    conn = redis.from_url(REDIS_URL)
    log(
        "GG Orchestrator started | redis=%s queue=%s->%s"
        % (REDIS_URL, REQUEST_QUEUE, RESULT_QUEUE)
    )
    while True:
        try:
            item = conn.blpop(REQUEST_QUEUE, timeout=5)
            if not item:
                continue
            _, raw = item
            task = json.loads(raw)
            log(f"got task: {task.get('action')} rid={task.get('run_id')}")
            handle_task(conn, task)
        except Exception as exc:  # pragma: no cover - defensive
            log(f"loop_error: {exc}")
            time.sleep(1)


if __name__ == "__main__":
    main()
PY

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" 
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.02luka.gg_local_bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PYTHON</string>
    <string>$AGENT_DIR/gg_orchestrator.py</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>REDIS_URL</key><string>redis://127.0.0.1:6379/0</string>
    <key>REQUEST_QUEUE</key><string>gg:requests</string>
    <key>RESULT_QUEUE</key><string>gg:results</string>
    <key>ALLOW_PATH_1</key><string>$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka</string>
    <key>ALLOW_PATH_2</key><string>$HOME/dev/02luka-repo</string>
  </dict>
  <key>StandardOutPath</key><string>$LOGDIR/stdout.log</string>
  <key>StandardErrorPath</key><string>$LOGDIR/stderr.log</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST

REDIS_OK=0
if command -v redis-cli >/dev/null 2>&1; then
  if redis-cli ping >/dev/null 2>&1; then
    REDIS_OK=1
  fi
fi

if [ $REDIS_OK -eq 0 ] && command -v docker >/dev/null 2>&1; then
  echo "Starting local Redis via Docker (if not exists)..."
  if ! docker ps --format '{{.Names}}' | grep -q '^luka-redis$'; then
    docker run -d --name luka-redis --restart unless-stopped -p 6379:6379 redis:7-alpine >/dev/null
  fi
fi

launchctl bootout "gui/$UID" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID" "$PLIST"
sleep 1

echo "== STATUS =="
echo "Logs  : $LOGDIR"
echo "Plist : $PLIST"
launchctl list | awk '$3 ~ /com.02luka.gg_local_bridge/ {print}'

cat > "$AGENT_DIR/gg_send.py" <<'PY'
import json
import os
import sys
import uuid

import redis


REDIS_URL = os.environ.get("REDIS_URL", "redis://127.0.0.1:6379/0")
REQUEST_QUEUE = os.environ.get("REQUEST_QUEUE", "gg:requests")
conn = redis.from_url(REDIS_URL)

task = json.loads(sys.stdin.read())
task.setdefault("run_id", f"gg-{uuid.uuid4().hex[:8]}")
conn.lpush(REQUEST_QUEUE, json.dumps(task))
print(task["run_id"])
PY

cat > "$AGENT_DIR/gg_tail.py" <<'PY'
import json
import os
import sys
import redis


REDIS_URL = os.environ.get("REDIS_URL", "redis://127.0.0.1:6379/0")
RESULT_QUEUE = os.environ.get("RESULT_QUEUE", "gg:results")

targets = set(sys.argv[1:])
conn = redis.from_url(REDIS_URL)

while True:
    item = conn.brpop(RESULT_QUEUE, timeout=5)
    if not item:
        continue
    _, raw = item
    message = json.loads(raw)
    if not targets or message.get("run_id") in targets:
        print(json.dumps(message, ensure_ascii=False, indent=2))
PY

echo "✅ GG Local Bridge installed."
echo "Tip: send a test ->"
echo "  echo '{\"action\":\"create_file\",\"path\":\"$SOT/g/reports/HELLO_GG.md\",\"content\":\"Hello from GG Local\"}' | $PYTHON $AGENT_DIR/gg_send.py"
echo "  # then tail results -> $PYTHON $AGENT_DIR/gg_tail.py"

