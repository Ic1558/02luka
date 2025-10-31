#!/usr/bin/env python3
"""
Agent Listener Daemon
- Subscribes to Redis channels and dispatches each JSON task to agent_router.py
- Channels covered (subscribe list can be expanded safely):
    gg:agent_router, gg:nlp_router, gg:direct_router,
    kim:agent, telegram:agent, clc:agent, cls:agent
- Result publish: <incoming_channel>.result (optional), and always write receipts/results on disk.
"""

import os
import sys
import json
import time
import subprocess
import traceback
import re
from datetime import datetime
from pathlib import Path

# ---------- Config ----------
LUKA_HOME = Path(os.path.expanduser(os.getenv("LUKA_HOME", "~/LocalProjects/02luka_local_g/g")))
LOGDIR = Path(os.path.expanduser("~/02luka/logs/agent"))
RECEIPTS = LOGDIR / "receipts"
RESULTS = LOGDIR / "results"
RUNTIME_LOG = LOGDIR / "listener.log"
RECEIPTS.mkdir(parents=True, exist_ok=True)
RESULTS.mkdir(parents=True, exist_ok=True)
LOGDIR.mkdir(parents=True, exist_ok=True)

# Full path to redis-cli (LaunchAgents have minimal PATH)
REDIS_CLI = "/opt/homebrew/bin/redis-cli"

# Redis connection: prefer REDIS_URL else host/port/password
REDIS_URL = os.getenv("REDIS_URL")  # e.g., redis://:password@127.0.0.1:6379/0
REDIS_HOST = os.getenv("REDIS_HOST", "127.0.0.1")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASS = os.getenv("REDIS_PASSWORD", "changeme-02luka")  # default from your system

CHANNELS = [
    "gg:agent_router",
    "gg:nlp_router",
    "gg:direct_router",
    "kim:agent",
    "telegram:agent",
    "clc:agent",
    "cls:agent",
]

ROUTER = LUKA_HOME / "agent_router.py"
DEFAULT_TIMEOUT = 180  # seconds per job

# ---------- Safety ----------
def assert_local_blob(s: str):
    """Block CloudStorage paths"""
    if not s:
        return
    if re.search(r"Library/CloudStorage|My Drive/02luka", s):
        raise RuntimeError("Blocked non-local CloudStorage path found in payload")

def safe_log(line: str):
    """Append to listener.log with timestamp"""
    RUNTIME_LOG.parent.mkdir(parents=True, exist_ok=True)
    with RUNTIME_LOG.open("a", encoding="utf-8") as f:
        f.write(f"{datetime.now().isoformat()} {line}\n")

# ---------- Minimal Redis client with graceful fallback ----------
def build_redis_client():
    """Try redis-py first, fallback to redis-cli"""
    try:
        import redis
        if REDIS_URL:
            client = redis.Redis.from_url(REDIS_URL, decode_responses=True)
        else:
            client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                password=REDIS_PASS if REDIS_PASS else None,
                decode_responses=True
            )
        # Quick ping test
        client.ping()
        return ("redispy", client)
    except Exception as e:
        safe_log(f"[warn] redis-py unavailable or ping failed: {e}. Falling back to redis-cli.")
        return ("cli", None)

def cli_pub(channel: str, payload: str):
    """Publish using redis-cli"""
    try:
        if REDIS_PASS:
            cmd = [REDIS_CLI, "-a", REDIS_PASS, "PUBLISH", channel, payload]
        else:
            cmd = [REDIS_CLI, "PUBLISH", channel, payload]
        subprocess.run(cmd, check=False, capture_output=True)
    except Exception as e:
        safe_log(f"[warn] cli_pub failed: {e}")

def cli_subscribe_loop(channels):
    """Blocking subscribe using redis-cli; yields (channel, message)"""
    base = [REDIS_CLI]
    if REDIS_PASS:
        base += ["-a", REDIS_PASS]
    base += ["SUBSCRIBE"] + channels

    proc = subprocess.Popen(base, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    # redis-cli SUBSCRIBE outputs lines like:
    # 1) "message"
    # 2) "<channel>"
    # 3) "<payload>"
    buf = []
    for raw in proc.stdout:
        line = raw.strip()
        if not line:
            continue
        buf.append(line)
        if len(buf) >= 3 and buf[-3].endswith('"message"'):
            # Parse channel and payload
            ch_line = buf[-2]
            pl_line = buf[-1]

            def extract(s):
                q1 = s.find('"')
                q2 = s.rfind('"')
                return s[q1+1:q2] if q1 >= 0 and q2 > q1 else ""

            ch = extract(ch_line)
            msg = extract(pl_line)
            yield (ch, msg)

def write_json(path: Path, obj):
    """Write JSON to file"""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)

def run_router(task_json: dict, task_id: str):
    """Invoke agent_router.py as a one-shot executor"""
    t0 = time.time()
    try:
        # Safety: local-only check on the raw payload
        assert_local_blob(json.dumps(task_json, ensure_ascii=False))

        # Force task_id in payload (router also generates its own if absent)
        if "task_id" not in task_json:
            task_json["task_id"] = task_id

        # Run router (stdin JSON)
        proc = subprocess.run(
            [sys.executable, str(ROUTER)],
            input=json.dumps(task_json).encode(),
            capture_output=True,
            timeout=task_json.get("timeout_s", DEFAULT_TIMEOUT)
        )

        out = proc.stdout.decode("utf-8", "ignore") or "{}"
        try:
            data = json.loads(out)
        except Exception:
            data = {
                "ok": False,
                "error": f"Non-JSON router output: {out[:200]}",
                "stdout": out,
                "stderr": proc.stderr.decode("utf-8", "ignore")
            }

        data.setdefault("task_id", task_id)
        data.setdefault("duration_ms", int((time.time() - t0) * 1000))
        return data

    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "task_id": task_id,
            "error": "router timeout",
            "duration_ms": int((time.time() - t0) * 1000)
        }
    except Exception as e:
        return {
            "ok": False,
            "task_id": task_id,
            "error": f"listener exception: {e}",
            "trace": traceback.format_exc(),
            "duration_ms": int((time.time() - t0) * 1000)
        }

def normalize_message(channel: str, raw: str):
    """Accepts either JSON text or plain intent. Returns normalized task dict."""
    try:
        msg = json.loads(raw)
        # Ensure fields
        msg.setdefault("intent", msg.get("command") or msg.get("action") or "unknown")
        msg.setdefault("origin_channel", channel)
        return msg
    except Exception:
        # Treat raw as simple intent string
        return {"intent": raw.strip(), "origin_channel": channel}

def main():
    """Main listener loop"""
    mode, client = build_redis_client()
    safe_log(f"[start] agent_listener using mode={mode} channels={CHANNELS}")

    if mode == "redispy":
        pubsub = client.pubsub(ignore_subscribe_messages=True)
        pubsub.subscribe(*CHANNELS)

        for m in pubsub.listen():
            try:
                if m.get("type") != "message":
                    continue

                ch = m["channel"]
                raw = m["data"]
                task = normalize_message(ch, raw)
                task_id = task.get("task_id") or f"lsn_{int(time.time() * 1000)}"

                # Write receipt
                write_json(RECEIPTS / f"{task_id}.json", {"channel": ch, "received": task})

                # Execute via router
                res = run_router(task, task_id)

                # Write result
                write_json(RESULTS / f"{task_id}.json", {"channel": ch, "result": res})

                # Publish result back
                client.publish(f"{ch}.result", json.dumps(res, ensure_ascii=False))

                safe_log(f"[done] {task_id} ch={ch} intent={task.get('intent')} ok={res.get('ok')}")

            except Exception as e:
                safe_log(f"[error] listen loop: {e}\n{traceback.format_exc()}")
    else:
        # redis-cli loop
        for ch, raw in cli_subscribe_loop(CHANNELS):
            try:
                task = normalize_message(ch, raw)
                task_id = task.get("task_id") or f"lsn_{int(time.time() * 1000)}"

                # Write receipt
                write_json(RECEIPTS / f"{task_id}.json", {"channel": ch, "received": task})

                # Execute via router
                res = run_router(task, task_id)

                # Write result
                write_json(RESULTS / f"{task_id}.json", {"channel": ch, "result": res})

                # Publish result back
                cli_pub(f"{ch}.result", json.dumps(res, ensure_ascii=False))

                safe_log(f"[done] {task_id} ch={ch} intent={task.get('intent')} ok={res.get('ok')}")

            except Exception as e:
                safe_log(f"[error] cli loop: {e}\n{traceback.format_exc()}")

if __name__ == "__main__":
    main()
