#!/usr/bin/env python3
import os, sys, json, subprocess, yaml

MAP = os.path.join(os.environ.get("LUKA_HOME",""), "misc", "nlp", "nlp_command_map.yaml")

def publish(channel, msg: str):
    # ใช้ redis-cli เป็นหลัก
    for binpath in ("/opt/homebrew/bin/redis-cli", "redis-cli"):
        try:
            p = subprocess.run([binpath,"PUBLISH",channel,msg],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if p.returncode == 0:
                return
        except Exception:
            pass
    raise SystemExit("redis-cli not found in PATH")

def main():
    raw = sys.stdin.read().strip()
    # รับ JSON {"text": "..."} หรือสตริงดิบ
    try:
        data = json.loads(raw)
        text = data.get("text") or data.get("q") or data.get("query") or raw
    except Exception:
        text = raw

    intent = None
    try:
        with open(MAP, "r", encoding="utf-8") as f:
            m = yaml.safe_load(f) or {}
        intent = m.get(text) or m.get((text or "").lower())
    except Exception:
        pass

    payload = {"intent": intent} if intent else {"text": text, "note": "fallback"}
    publish("gg:agent_router", json.dumps(payload, ensure_ascii=False))

if __name__ == "__main__":
    main()
