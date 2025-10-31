#!/usr/bin/env python3
import os, json, time, uuid, re, yaml, redis, subprocess

REDIS_HOST=os.getenv("REDIS_HOST","localhost")
REDIS_PORT=int(os.getenv("REDIS_PORT","6379"))
REDIS_PASSWORD=os.getenv("REDIS_PASSWORD","")
NLP_IN_CH=os.getenv("NLP_IN_CHANNEL","gg:nlp")
SHELL_OUT_CH=os.getenv("SHELL_OUT_CHANNEL","shell")
SHELL_RESP_CH=os.getenv("SHELL_RESP_CHANNEL","shell:response:shell")
MAP_PATH=os.path.expanduser("~/02luka/core/nlp/nlp_command_map.yaml")

def load_map():
    with open(MAP_PATH,"r",encoding="utf-8") as f: return yaml.safe_load(f)

def norm(t:str)->str:
    t=t.strip().lower()
    t=re.sub(r"\s+"," ",t)
    return t

def match_intent(txt:str,m)->(str,str,str):
    """Returns (intent_name, command, needs_confirm)"""
    txt=norm(txt)
    for name,spec in (m.get("intents") or {}).items():
        for kw in spec.get("patterns",[]):
            if kw.lower() in txt:
                cmd = spec["action"]["cmd"]
                confirm = spec.get("confirm",False)
                return (name, cmd, confirm)
    fallback_cmd = (m.get("fallback") or {}).get("command","clcctl status")
    return ("fallback", fallback_cmd, False)

def execute_with_response(intent:str, cmd:str):
    """Execute command and send response via summarizer"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=120
        )
        output = result.stdout + result.stderr
        exit_code = result.returncode

        # Send to response summarizer
        summarizer = os.path.expanduser("~/02luka/tools/nlp_response_summarizer.zsh")
        if os.path.exists(summarizer):
            subprocess.run(
                [summarizer, intent, str(exit_code)],
                input=output, text=True
            )

        return (exit_code, output)
    except Exception as e:
        return (1, f"Error: {e}")

def main():
    mapping=load_map()
    if REDIS_PASSWORD:
        r=redis.Redis(host=REDIS_HOST,port=REDIS_PORT,password=REDIS_PASSWORD,decode_responses=True)
    else:
        r=redis.Redis(host=REDIS_HOST,port=REDIS_PORT,decode_responses=True)
    print(f"[NLP] Redis {REDIS_HOST}:{REDIS_PORT} listening {NLP_IN_CH} -> shell+telegram",flush=True)
    ps=r.pubsub(); ps.subscribe(NLP_IN_CH)
    last_mtime=os.path.getmtime(MAP_PATH)

    for msg in ps.listen():
        # hot-reload on change
        try:
            mt=os.path.getmtime(MAP_PATH)
            if mt!=last_mtime:
                mapping=load_map(); last_mtime=mt
                print("[NLP] mapping reloaded",flush=True)
        except Exception: pass

        if msg.get("type")!="message": continue
        raw=msg.get("data","")
        try:
            text=raw
            if isinstance(raw,str) and raw.startswith("{"):
                obj=json.loads(raw); text=obj.get("text","")

            intent, cmd, needs_confirm = match_intent(text, mapping)

            if needs_confirm:
                print(f"[NLP] '{text}' -> {intent} (CONFIRM REQUIRED)",flush=True)
                # TODO: implement confirmation flow via Telegram
                continue

            # Fallback: publish unmatched intents to agent_router for listener
            if intent == "fallback":
                print(f"[NLP] '{text}' -> FALLBACK, publishing to gg:agent_router",flush=True)
                try:
                    payload = json.dumps({"intent": text, "source": "nlp", "origin_channel": NLP_IN_CH})
                    r.publish("gg:agent_router", payload)
                    print(f"[NLP] Published to gg:agent_router: {payload}",flush=True)
                except Exception as pub_err:
                    print(f"[NLP][ERR] Failed to publish fallback: {pub_err}",flush=True)
                    # Try redis-cli as backup
                    try:
                        subprocess.run(
                            ["redis-cli", "-a", REDIS_PASSWORD, "PUBLISH", "gg:agent_router", payload],
                            check=False, capture_output=True
                        )
                    except Exception as cli_err:
                        print(f"[NLP][ERR] redis-cli fallback failed: {cli_err}",flush=True)
                continue

            print(f"[NLP] '{text}' -> {intent}: {cmd}",flush=True)
            exit_code, output = execute_with_response(intent, cmd)
            print(f"[NLP] {intent} completed (exit={exit_code})",flush=True)

        except Exception as e:
            print(f"[NLP][ERR] {e} :: raw={raw}",flush=True)

if __name__=="__main__":
    main()
