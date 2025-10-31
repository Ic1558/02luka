#!/usr/bin/env python3
import os, sys, json, yaml, redis, time
LUKA_HOME = os.environ.get("LUKA_HOME", "/Users/icmini/LocalProjects/02luka_local_g/g")
MAP = os.path.join(LUKA_HOME, "misc/nlp/nlp_command_map.yaml")
def main():
    raw = sys.stdin.read() or "{}"
    try: msg = json.loads(raw)
    except: msg = {"text": raw.strip()}
    text = (msg.get("text") or "").strip()
    intent = None
    try:
        with open(MAP, "r", encoding="utf-8") as f:
            m = yaml.safe_load(f) or {}
        intent = m.get(text) or m.get(text.lower())
    except: pass
    payload = {"intent": intent} if intent else {"text": text, "note":"fallback"}
    r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
    ch = "gg:agent_router" if intent else "gg:agent_router"  # fallback same channel
    r.publish(ch, json.dumps(payload, ensure_ascii=False))
if __name__ == "__main__": main()
