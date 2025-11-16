# MLS Live UI - Kim Chat Integration Setup

**Date:** 2025-11-05
**Version:** v2.2.0 + Kim Chat
**Status:** ✅ Ready for Testing

---

## 🎯 What Was Built

Added a **floating chat widget** to the MLS Live UI that connects to **Kim Agent** (your local NLP/dispatcher) via Redis.

### Architecture Flow

```
MLS Live UI (Browser)
    ↓ HTTP POST
Kim UI Shim (Flask:8770)
    ↓ Redis Publish (kim:requests)
Kim Agent (Listening)
    ↓ NLP + Routing
Mary / CLC / Paula / GC
    ↓ Redis Reply (kim:reply:*)
Kim UI Shim
    ↓ HTTP Response
MLS Live UI (Display)
```

---

## 📦 Files Created/Modified

### 1. `/Users/icmini/02luka/g/reports/mls_report_20251105.html`
**Modified** - Added chat widget with:
- Floating chat button (bottom-right)
- Side panel chat interface
- Context scope toggle (Current/All entries)
- Intent parser (add_solution, add_failure, search, etc.)
- Auto-focus on open

### 2. `/Users/icmini/02luka/tools/kim_ui_shim.py` ✨ NEW
**Created** - Flask HTTP → Redis bridge:
- Listens on `http://127.0.0.1:8770`
- Endpoint: `/kim/chat` (POST)
- Health check: `/health` (GET)
- Publishes to: `kim:requests`
- Waits for reply on: `kim:reply:{correlation_id}`
- 8-second timeout for synchronous replies

---

## 🚀 How to Start

### 1. Ensure Prerequisites

```bash
# Redis running
redis-cli -a gggclukaic PING
# Should return: PONG

# API server running (for MLS data)
ps aux | grep api_server.py
# Should show PID on port 8767
```

### 2. Start Kim UI Shim

```bash
cd ~/02luka/tools
python3 kim_ui_shim.py

# Or run in background:
nohup python3 kim_ui_shim.py > ~/02luka/logs/kim_ui_shim.out.log 2>&1 &
```

**Expected output:**
```
============================================================
Kim UI Shim - MLS Live Chat Bridge
============================================================
Listening on: http://127.0.0.1:8770
Kim ingress channel: kim:requests
Redis: 127.0.0.1:6379
============================================================
✅ Redis connection OK

Starting Flask server...
```

### 3. Verify Services

```bash
# Test Kim shim health
curl http://127.0.0.1:8770/health
# Expected: {"redis":"connected","status":"ok"}

# Test MLS API
curl http://127.0.0.1:8767/api/mls | jq .summary
# Expected: {"total":14,"solutions":9,...}
```

### 4. Open MLS Live UI

```bash
open file:///Users/icmini/02luka/g/reports/mls_report_20251105.html
# OR
open http://127.0.0.1:8767  # if served via API server
```

---

## 💬 Using the Chat

### Opening the Chat

1. Click the **"💬 Chat"** button in the bottom-right corner
2. Chat panel slides in from the right
3. Type messages in the textarea

### Context Scope

- **Current** (default): Only sends expanded MLS entries as context
- **All entries**: Sends all 14 MLS entries as context

Click the chips to toggle between modes.

### Intent Keywords

The UI auto-detects intent from your message:

| Message Pattern | Intent | Action |
|----------------|--------|--------|
| `add solution: ...` | `add_solution` | Kim creates new MLS solution entry |
| `add failure: ...` | `add_failure` | Kim creates new MLS failure entry |
| `add pattern: ...` | `add_pattern` | Kim creates new MLS pattern entry |
| `add improvement: ...` | `add_improvement` | Kim creates new MLS improvement entry |
| `search: ...` | `search` | Kim searches MLS entries |
| Everything else | `chat` | General Q&A with context |

### Example Messages

```
"What are the recent solutions?"
"add solution: Fixed Redis timeout by increasing connection pool"
"search: Google Drive sync"
"Why did WO-251105 succeed?"
```

---

## 🔧 Kim Agent Integration

### Payload Format

The shim sends this JSON to Kim:

```json
{
  "type": "kim_nlp_request",
  "reply_to": "kim:reply:kim_ui_abc123",
  "correlation_id": "kim_ui_abc123",
  "source": "mls_live_ui",
  "ts": 1730779200,
  "user": "Boss",
  "message": {
    "text": "add solution: Fixed Redis timeout",
    "intent": "add_solution",
    "context": {
      "entries": [
        {"id":"MLS-123","type":"solution","title":"..."},
        ...
      ]
    },
    "meta": {"source":"mls_live_ui","ts":1730779200000}
  }
}
```

### Kim Handler (Pseudocode)

Kim should handle `type: "kim_nlp_request"` with `source: "mls_live_ui"`:

```python
def on_kim_nlp_request(msg):
    text = msg["message"]["text"]
    intent = msg["message"]["intent"]
    context_entries = msg["message"]["context"]["entries"]

    # Route based on intent
    if intent == "add_solution":
        # Create new MLS entry
        new_entry = create_mls_entry(
            type="solution",
            title=extract_title(text),
            description=text,
            context=context_entries
        )
        reply = f"✅ Created {new_entry['id']}"

    elif intent == "search":
        # Search existing entries
        results = search_mls(text, context_entries)
        reply = format_search_results(results)

    else:  # chat
        # General Q&A with context
        reply = ask_ai(text, context=context_entries)

    # Publish reply
    redis.publish(msg["reply_to"], json.dumps({
        "role": "assistant",
        "content": reply
    }))
```

---

## 📊 Current Status

### ✅ Completed

- [x] MLS Live UI chat widget (HTML/CSS/JS)
- [x] Kim UI shim Flask server
- [x] Redis pub/sub integration
- [x] Intent parsing (5 patterns)
- [x] Context scope toggle (Current/All)
- [x] CORS headers for local development
- [x] Health check endpoint
- [x] Error handling and timeouts
- [x] Auto-refresh every 30 seconds (MLS data)

### ⏳ Pending (Kim Side)

- [ ] Kim agent subscribes to `kim:requests`
- [ ] Kim handles `kim_nlp_request` type
- [ ] Kim routes intents to Mary/CLC/Paula
- [ ] Kim publishes replies to `kim:reply:*`
- [ ] Kim writes new MLS entries to `mls_lessons.jsonl`

---

## 🧪 Testing Checklist

### Without Kim (Mock Mode)

1. **Open UI**: Chat button appears bottom-right
2. **Click Chat**: Panel slides in from right
3. **Type message**: Hit Send
4. **Expected**: Error message or timeout (Kim not listening)

### With Kim (Full Integration)

1. **Start Kim agent**: Ensure it subscribes to `kim:requests`
2. **Send "Hello Kim"**: Should get AI reply within 8 seconds
3. **Send "add solution: Test"**: Kim creates new MLS entry
4. **Wait 30 seconds**: UI auto-refreshes, new entry appears
5. **Expand entry**: Click "Current" chip, send question
6. **Expected**: Kim uses only that entry as context

---

## 🔍 Troubleshooting

### Chat shows "❌ Error: Failed to fetch"

**Cause:** Kim UI shim not running
**Fix:** Start `python3 ~/02luka/tools/kim_ui_shim.py`

### Chat shows "⏳ Queued to Kim. You'll see updates shortly."

**Cause:** Kim agent not listening on `kim:requests`
**Fix:** Start Kim agent or check channel name in `kim_ui_shim.py` (line 31)

### Chat hangs for 8 seconds then times out

**Cause:** Kim received message but didn't reply to `kim:reply:*` channel
**Fix:** Verify Kim publishes to the `reply_to` channel in the payload

### MLS data not loading

**Cause:** API server not running
**Fix:** Start `python3 ~/02luka/g/apps/dashboard/api_server.py`

### Redis connection failed

**Cause:** Redis not running or wrong password
**Fix:** Check `redis-cli -a gggclukaic PING`

---

## 📝 Configuration

### Change Kim Ingress Channel

Edit `/Users/icmini/02luka/tools/kim_ui_shim.py` line 31:

```python
INGRESS = "kim:requests"  # Change to your Kim channel
```

### Change Timeout

Edit `/Users/icmini/02luka/tools/kim_ui_shim.py` line 32:

```python
TIMEOUT_S = 8  # Increase if Kim is slow
```

### Change Shim Port

Edit `/Users/icmini/02luka/tools/kim_ui_shim.py` line 113:

```python
APP.run(host="127.0.0.1", port=8770)  # Change port
```

And update UI `/Users/icmini/02luka/g/reports/mls_report_20251105.html` line 350:

```javascript
endpoint: 'http://127.0.0.1:8770/kim/chat',  // Match shim port
```

---

## 🎯 Next Steps

1. **Test Kim Integration**: Ensure Kim listens to `kim:requests`
2. **Implement Intent Handlers**: Add logic in Kim for `add_solution`, `search`, etc.
3. **Add Write-Back**: Have Kim write new entries to `mls_lessons.jsonl`
4. **Live Updates**: Publish to `mls:updates` so UI refreshes instantly
5. **Enhance UI**: Add typing indicator, message timestamps, user avatars

---

## 📚 Related Files

- **MLS Live UI**: `/Users/icmini/02luka/g/reports/mls_report_20251105.html`
- **Kim Shim**: `/Users/icmini/02luka/tools/kim_ui_shim.py`
- **API Server**: `/Users/icmini/02luka/g/apps/dashboard/api_server.py`
- **MLS Data**: `/Users/icmini/02luka/g/knowledge/mls_lessons.jsonl`
- **Logs**: `~/02luka/logs/kim_ui_shim.out.log`

---

**Built by:** CLC (Claude Code)
**Date:** 2025-11-05
**Integration:** MLS Live UI + Kim Agent via Redis
