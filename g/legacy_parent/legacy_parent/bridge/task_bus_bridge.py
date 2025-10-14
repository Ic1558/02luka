#!/usr/bin/env python3
"""
Mirrors task events between Redis Pub/Sub (channel: mcp:tasks)
and the file memory (active_tasks.json/.jsonl).
- If Redis is present: subscribe and write to files.
- Also polls the JSONL file for new lines and republishes to Redis (de-duped).
"""
import os, sys, time, json, threading, hashlib
from datetime import datetime

SOT = os.environ.get("SOT", os.path.expanduser("~/dev/02luka-repo"))
MEM = os.environ.get("MEM", os.path.join(SOT, "a/memory"))
LOGD = os.environ.get("LOGD", os.path.expanduser("~/Library/Logs/02luka"))
os.makedirs(MEM, exist_ok=True)
os.makedirs(LOGD, exist_ok=True)
jsonl_path = os.path.join(MEM, "active_tasks.jsonl")
snap_path  = os.path.join(MEM, "active_tasks.json")
log_path   = os.path.join(LOGD, "task_bus_bridge.log")

# lightweight logger
def log(msg):
    ts = datetime.now().isoformat()
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(f"[{ts}] {msg}\n")

# state for de-dupe
seen = set()
def fingerprint(obj):
    try:
        s = json.dumps(obj, sort_keys=True)
        return hashlib.sha1(s.encode()).hexdigest()
    except Exception:
        return None

# update files
def append_and_snapshot(ev):
    os.makedirs(MEM, exist_ok=True)
    with open(jsonl_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(ev, ensure_ascii=False) + "\n")
    # snapshot last N per agent
    N = int(os.environ.get("N_LAST", "20"))
    try:
        # tail-ish read (safe on moderate file sizes)
        with open(jsonl_path, "r", encoding="utf-8") as f:
            lines = f.readlines()[-1000:]
        events = [json.loads(x) for x in lines if x.strip()]
        events.sort(key=lambda e: e.get("ts",""))
        by_agent = {}
        for e in events:
            by_agent.setdefault(e.get("agent","unknown"), []).append(e)
        last = []
        for a, arr in by_agent.items():
            last.extend(arr[-N:])
        snap = {"timestamp": datetime.utcnow().isoformat()+"Z", "tasks": last}
        tmp = snap_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(snap, f, ensure_ascii=False)
        os.replace(tmp, snap_path)
    except Exception as e:
        log(f"snapshot error: {e}")

# publisher (Redis optional)
class Publisher:
    def __init__(self):
        self.r = None
        try:
            import redis
            url = os.environ.get("REDIS_URL")  # e.g. redis://:pass@127.0.0.1:6379/0
            if url:
                self.r = redis.from_url(url)
            else:
                host = os.environ.get("REDIS_HOST","127.0.0.1")
                port = int(os.environ.get("REDIS_PORT","6379"))
                pwd  = os.environ.get("REDIS_PASSWORD") or None
                self.r = redis.Redis(host=host, port=port, password=pwd)
            # quick ping
            self.r.ping()
            log("redis: connected")
        except Exception as e:
            log(f"redis: not available ({e})")
            self.r = None

    def publish(self, ch, obj):
        if not self.r: return
        try:
            self.r.publish(ch, json.dumps(obj, ensure_ascii=False))
        except Exception as e:
            log(f"publish error: {e}")

# subscriber thread
def sub_thread(pub):
    if not pub.r:
        log("subscriber disabled (no redis)")
        return
    try:
        p = pub.r.pubsub()
        p.subscribe("mcp:tasks")
        log("subscribing mcp:tasks")
        for m in p.listen():
            if m["type"] != "message": continue
            try:
                ev = json.loads(m["data"])
                fp = fingerprint(ev)
                if fp and fp in seen: continue
                if fp: seen.add(fp)
                append_and_snapshot(ev)
            except Exception as e:
                log(f"sub decode error: {e}")
    except Exception as e:
        log(f"sub thread error: {e}")

# file tailer thread -> republishes to redis
def file_thread(pub):
    last_size = 0
    while True:
        try:
            size = os.path.getsize(jsonl_path) if os.path.exists(jsonl_path) else 0
            if size > last_size:
                with open(jsonl_path, "r", encoding="utf-8") as f:
                    f.seek(last_size)
                    new = f.read()
                last_size = size
                for line in new.splitlines():
                    if not line.strip(): continue
                    try:
                        ev = json.loads(line)
                        fp = fingerprint(ev)
                        if fp and fp in seen: continue
                        if fp: seen.add(fp)
                        pub.publish("mcp:tasks", ev)
                    except Exception as e:
                        log(f"tail decode error: {e}")
        except Exception as e:
            log(f"tail error: {e}")
        time.sleep(0.8)

def main():
    pub = Publisher()
    # ensure files exist
    if not os.path.exists(jsonl_path):
        open(jsonl_path,"a",encoding="utf-8").close()
    if not os.path.exists(snap_path):
        with open(snap_path,"w",encoding="utf-8") as f:
            json.dump({"timestamp": datetime.utcnow().isoformat()+"Z","tasks":[]}, f)
    # threads
    t1 = threading.Thread(target=sub_thread, args=(pub,), daemon=True)
    t2 = threading.Thread(target=file_thread, args=(pub,), daemon=True)
    t1.start(); t2.start()
    log("task_bus_bridge running")
    # heartbeat
    try:
        while True:
            time.sleep(5)
    except KeyboardInterrupt:
        log("bridge stopped")

if __name__ == "__main__":
    main()
