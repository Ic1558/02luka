import json, subprocess, time, os, sys
from pathlib import Path

SOT = Path(os.environ.get("LUKA_SOT", str(Path.home()/"02luka")))
MEM_TOOL = SOT / "tools" / "memory_sync.sh"
INBOX = SOT / "bridge" / "memory" / "inbox"

def _run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout

def before_task():
    out = _run([str(MEM_TOOL), "get"])
    return json.loads(out)

def after_task(task_result: dict):
    try:
        _run([str(MEM_TOOL), "update", "cls", "active"])
    except Exception as e:
        print(f"WARN: memory_sync failed: {e}", file=sys.stderr)
    ts = int(time.time() * 1000)  # milliseconds for uniqueness
    INBOX.mkdir(parents=True, exist_ok=True)
    (INBOX / f"cls_result_{ts}.json").write_text(json.dumps(task_result, indent=2))

if __name__ == "__main__":
    print(json.dumps(before_task())[:200])
    after_task({"ok": True, "ts": int(time.time())})
    print("cls_memory: ok")
