#!/usr/bin/env zsh
# 02luka WO dropper — Hybrid Mobile Ingest (Kim + HTTPS Inbox) with Auto-Trigger
set -euo pipefail

WO_ID="WO-$(date +%y%m%d)-MOBILE-BRIDGE-V1"
BASE="$HOME/02luka"
INBOX="$BASE/bridge/inbox/CLC"
HIST="$BASE/logs/wo_drop_history"
TMP="$(mktemp -d)"
WO_FILE="$TMP/${WO_ID}.json"

mkdir -p "$INBOX" "$HIST"

# --- helper: random bearer if needed (32 hex) ---
gen_bearer() { openssl rand -hex 32 | tr -d '\n'; }

# write WO JSON
cat > "$WO_FILE" <<'JSON'
{
  "wo_id": "__WO_ID__",
  "title": "Hybrid Mobile Ingest: Kim + HTTPS Inbox + Auto-Trigger via Redis",
  "requested_by": "GG",
  "priority": "P0",
  "actions": [
    {
      "type": "ensure_env",
      "path": "~/02luka/.env.local",
      "vars": {
        "MOBILE_INBOX_BEARER": "__AUTO_OR_KEEP__",
        "REDIS_URL": "redis://:gggclukaic@127.0.0.1:6379"
      },
      "notes": "Create MOBILE_INBOX_BEARER if missing; keep existing if present."
    },
    {
      "type": "patch_file",
      "mode": "sip",
      "path": "~/02luka/boss-api/server.cjs",
      "description": "Add POST /api/mobile-inbox with Bearer auth and Redis publish",
      "snippet_id": "boss_api_mobile_inbox_route_v1",
      "insert": {
        "search": "/* MOBILE_INBOX_ROUTE_ANCHOR */",
        "fallback": "end_of_file",
        "content": "/* MOBILE_INBOX_ROUTE_ANCHOR */\nimport crypto from 'crypto';\nimport bodyParser from 'body-parser';\nimport Redis from 'ioredis';\napp.use(bodyParser.json({ limit: '5mb' }));\nconst REQUIRED_BEARER = process.env.MOBILE_INBOX_BEARER || 'changeme-very-secret';\nconst REDIS_URL = process.env.REDIS_URL || 'redis://:gggclukaic@127.0.0.1:6379';\nconst redis = new Redis(REDIS_URL);\nfunction validPayload(p){return p && typeof p==='object' && typeof p.content==='string' && typeof p.agent==='string';}\napp.post('/api/mobile-inbox', async (req,res)=>{\n  try{\n    const hdr=(req.headers.authorization||'').replace(/^Bearer\\s+/i,'');\n    if(hdr!==REQUIRED_BEARER) return res.status(401).json({error:'unauthorized'});\n    const p=req.body; if(!validPayload(p)) return res.status(400).json({error:'bad payload'});\n    const msg={ id: crypto.randomUUID(), channel:'mobile:inbox', agent:p.agent, task:p.task||'trading_note', content:p.content, images:p.images||[], meta:{from:p.from||'iphone', period:p.period||null, symbol:p.symbol||null, source:'mobile/https'}, ts:new Date().toISOString() };\n    await redis.publish('mobile:inbox', JSON.stringify(msg));\n    return res.json({ok:true,id:msg.id});\n  }catch(e){ console.error('mobile-inbox error',e); return res.status(500).json({error:'server_error'}); }\n});\n"
      }
    },
    {
      "type": "patch_file",
      "mode": "sip",
      "path": "~/02luka/agents/task_bus_bridge.py",
      "description": "Subscribe mobile:inbox and route to paula:queue",
      "snippet_id": "task_bus_bridge_mobile_route_v1",
      "insert": {
        "search": "# TASK_BUS_SUBSCRIBE_ANCHOR",
        "fallback": "end_of_file",
        "content": "# TASK_BUS_SUBSCRIBE_ANCHOR\nsubscribe_channels = sorted(list(set((globals().get('subscribe_channels') or []) + ['mobile:inbox','gg:requests'])))\n\n# ROUTING_ANCHOR\ndef route_message(ch, msg):\n    try:\n        import json, os\n        data = json.loads(msg)\n        if ch == 'mobile:inbox':\n            # default route: Paula queue\n            publish('paula:queue', json.dumps(data))\n        elif ch == 'gg:requests':\n            publish('mary:queue', json.dumps(data))\n    except Exception as e:\n        print('route_message error:', e)\n"
      }
    },
    {
      "type": "patch_file",
      "mode": "sip",
      "path": "~/02luka/agents/paula/listener.py",
      "description": "Ensure Paula subscribes paula:queue and persists to memory with summaries",
      "snippet_id": "paula_listener_queue_v1",
      "insert": {
        "search": "# PAULA_SUBSCRIBE_ANCHOR",
        "fallback": "end_of_file",
        "content": "# PAULA_SUBSCRIBE_ANCHOR\nsubscribe_channels = sorted(list(set((globals().get('subscribe_channels') or []) + ['paula:queue'])))\n\n# PAULA_HANDLER_ANCHOR\ndef handle_paula_queue(msg_str):\n    import json, os, datetime, pathlib\n    data = json.loads(msg_str)\n    symbol = (data.get('meta') or {}).get('symbol') or ''\n    period = (data.get('meta') or {}).get('period') or ''\n    content = data.get('content') or ''\n    now = datetime.datetime.now()\n    ddir = pathlib.Path(os.path.expanduser('~/02luka/memory/paula/mobile_inbox'))\n    ddir.mkdir(parents=True, exist_ok=True)\n    fpath = ddir / f\"{now.strftime('%Y-%m-%d')}.md\"\n    with open(fpath, 'a', encoding='utf-8') as f:\n        f.write(f\"\\n## {now.strftime('%H:%M')}  from:mobile  symbol:{symbol}  period:{period}\\n\")\n        f.write(f\"content: {content}\\n\")\n    # lightweight summary\n    sdir = pathlib.Path(os.path.expanduser('~/02luka/g/reports/mobile_entries'))\n    sdir.mkdir(parents=True, exist_ok=True)\n    with open(sdir / 'summary.md', 'a', encoding='utf-8') as f:\n        f.write(f\"- {now.strftime('%Y-%m-%d %H:%M')}  {symbol} {period}  (mobile)\\n\")\n"
      }
    },
    {
      "type": "patch_file",
      "mode": "sip",
      "path": "~/02luka/agents/kim/router.py",
      "description": "Map tags #PAULA #14d #VLM to unified task schema",
      "snippet_id": "kim_router_tags_v1",
      "insert": {
        "search": "# KIM_TAG_ROUTER_ANCHOR",
        "fallback": "end_of_file",
        "content": "# KIM_TAG_ROUTER_ANCHOR\n# simple tag mapping (idempotent)\ndef map_tags_to_task(text):\n    t = text.lower()\n    task = { 'agent':'paula', 'task':'trading_note', 'meta':{} }\n    if '#paula' in t: task['agent']='paula'\n    if '#gg' in t: task['agent']='gg'\n    if '#mary' in t: task['agent']='mary'\n    # period like #14d\n    import re\n    m = re.search(r'#(\\d+)(d|h|w)', t)\n    if m: task['meta']['period'] = m.group(1)+m.group(2)\n    if '#vlm' in t: task['task']='trading_note_vlm'\n    return task\n"
      }
    },
    {
      "type": "create_file",
      "path": "~/02luka/g/mobile/shortcuts/send_to_02luka.shortcut.json",
      "description": "iOS Shortcut spec (import manually)",
      "content_base64": "__EMBEDDED_SHORTCUT_JSON_BASE64__"
    },
    {
      "type": "reload_launchagents",
      "agents": [
        "com.02luka.boss.api",
        "com.02luka.task.bus.bridge",
        "com.02luka.paula.agent",
        "com.02luka.health.poller"
      ]
    },
    {
      "type": "create_file",
      "path": "~/02luka/tools/test_mobile_inbox_curl.sh",
      "description": "curl test script",
      "mode": "0755",
      "content": "#!/usr/bin/env bash\nset -euo pipefail\nHOST=${1:-\"https://YOUR-TUNNELLED-HOST\"}\nBEARER=${MOBILE_INBOX_BEARER:-\"changeme\"}\ncat <<EOF\nPOST -> $HOST/api/mobile-inbox\nEOF\ncurl -sS -X POST \"$HOST/api/mobile-inbox\" \\\n  -H \"Authorization: Bearer $BEARER\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"from\":\"iphone\",\"agent\":\"paula\",\"task\":\"trading_note\",\"symbol\":\"S50Z25\",\"period\":\"14d\",\"content\":\"S50Z25 looks bid; check OI ramp and Z-U spread.\",\"images\":[]}' | jq .\n"
    },
    {
      "type": "verify",
      "checks": [
        {"type":"file_contains","path":"~/02luka/boss-api/server.cjs","pattern":"app.post('/api/mobile-inbox'"},
        {"type":"launchagent_loaded","label":"com.02luka.task.bus.bridge"},
        {"type":"redis_pubsub","channel":"mobile:inbox","dry_run":true}
      ]
    }
  ]
}
JSON

# fill WO_ID and embed shortcut JSON + bearer marker
sed -i '' "s/__WO_ID__/${WO_ID}/g" "$WO_FILE"

# embed a minimal Shortcut JSON (base64) — text-only body; user can edit later in Shortcuts
SHORTCUT_JSON='{
  "name": "Send to 02luka",
  "actions": [
    {"type":"GetClipboard"},
    {"type":"Text","text":"${clipboard}"},
    {"type":"GetContentsOfURL",
     "url":"https://YOUR-TUNNELLED-HOST/api/mobile-inbox",
     "method":"POST",
     "headers":{"Authorization":"Bearer ${MOBILE_INBOX_BEARER}","Content-Type":"application/json"},
     "requestBody":{
       "from":"iphone","agent":"paula","task":"trading_note",
       "symbol":"S50Z25","period":"14d","content":"${clipboard}","images":[]
     }
    }
  ]
}'
b64_shortcut="$(printf "%s" "$SHORTCUT_JSON" | base64)"
sed -i '' "s#__EMBEDDED_SHORTCUT_JSON_BASE64__#${b64_shortcut}#g" "$WO_FILE"

# move WO into inbox atomically + audit copy
dest="$INBOX/${WO_ID}.json"
cp "$WO_FILE" "$HIST/${WO_ID}.json"
mv "$WO_FILE" "$dest"

echo "✅ Dropped: $dest"
echo "🗂  History: $HIST/${WO_ID}.json"

# list mailboxes
echo
echo "=== Bridge Folders ==="
ls -la "$INBOX" | tail -n +1
echo
echo "Next: CLC will pick it up and apply."
