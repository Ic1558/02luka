# Notification System v1.0 - Complete Flow Diagram

**Version:** 1.0  
**Date:** 2025-12-05  
**Status:** Production Ready

---

## 🔄 **COMPLETE SEQUENCE DIAGRAM**

```
┌─────────────┐
│  Opal App   │
│  (Cloud)    │
└─────┬───────┘
      │
      │ 1. User Input
      │    (objective, app_mode, priority, files)
      │
      ▼
┌─────────────────────┐
│ Generate JSON       │
│ Work Order          │
│ (AI Node)           │
└─────┬───────────────┘
      │
      │ 2. WO JSON Generated
      │    {wo_id, app_mode, objective, ...}
      │
      ▼
┌─────────────────────┐
│ Generate Notification│
│ Payload (AI Node)   │
└─────┬───────────────┘
      │
      │ 3. Notification JSON
      │    {wo_id, telegram: {chat, text, meta}}
      │
      ▼
┌─────────────────────┐
│ HTTP Request        │
│ POST /api/notify    │
└─────┬───────────────┘
      │
      │ 4. HTTPS POST
      │    Headers: X-Relay-Key, Content-Type
      │
      ▼
┌─────────────────────┐
│ Cloudflare Tunnel   │
│ gateway.theedges.work│
└─────┬───────────────┘
      │
      │ 5. Tunnel Forward
      │
      ▼
┌─────────────────────┐
│ Gateway (Flask)     │
│ localhost:5001      │
│ /api/notify         │
└─────┬───────────────┘
      │
      │ 6. Security Checks
      │    ✅ RELAY_KEY validation
      │    ✅ CloudStorage path blocking
      │    ✅ Input validation
      │
      │ 7. Atomic Write
      │    bridge/inbox/NOTIFY/{wo_id}_notify.json
      │
      ▼
┌─────────────────────┐
│ Notification File   │
│ bridge/inbox/       │
│ NOTIFY/             │
│ {wo_id}_notify.json │
└─────┬───────────────┘
      │
      │ 8. File Created
      │    (atomic: .tmp → rename)
      │
      ▼
┌─────────────────────┐
│ Notification Worker │
│ notify_worker.zsh   │
│ (Polling: 5s)       │
└─────┬───────────────┘
      │
      │ 9. Worker Detects File
      │    (skips .tmp files)
      │
      │ 10. Stale Check
      │     ✅ < 24h → Process
      │     ❌ > 24h → Skip, move to failed/
      │
      │ 11. Read JSON Payload
      │     Extract: chat, text, meta
      │
      │ 12. Resolve Chat ID
      │     resolve_chat_id("boss_private")
      │     → TELEGRAM_SYSTEM_ALERT_CHAT_ID
      │
      │ 13. Resolve Bot Token
      │     resolve_bot_token("boss_private")
      │     → TELEGRAM_SYSTEM_ALERT_BOT_TOKEN
      │
      │ 14. Send Telegram (with retry)
      │     POST https://api.telegram.org/bot{token}/sendMessage
      │     Retry: 3 attempts, exponential backoff
      │
      ▼
┌─────────────────────┐
│ Telegram Bot API    │
│ api.telegram.org    │
└─────┬───────────────┘
      │
      │ 15. HTTP 200 OK
      │     Message delivered
      │
      ▼
┌─────────────────────┐
│ Telegram Chat       │
│ boss_private        │
│ (User receives)     │
└─────────────────────┘
      │
      │ 16. Log Metrics
      │     g/telemetry/notify_worker.jsonl
      │     {result: "success", attempts: 1, http_code: 200}
      │
      │ 17. Move File
      │     bridge/processed/NOTIFY/{wo_id}_notify.json
      │
      ▼
┌─────────────────────┐
│ Success ✅          │
│ Notification Sent   │
└─────────────────────┘
```

---

## 📊 **DETAILED FLOW STEPS**

### **Phase 1: Opal App → Gateway**

| Step | Component | Action | Data |
|------|-----------|--------|------|
| 1 | Opal User | Input: objective, app_mode, priority | User input |
| 2 | Opal AI | Generate Work Order JSON | `{wo_id, app_mode, objective, ...}` |
| 3 | Opal AI | Generate Notification Payload | `{wo_id, telegram: {chat, text, meta}}` |
| 4 | Opal HTTP | POST to Cloudflare Tunnel | Headers + JSON body |
| 5 | Cloudflare | Forward to Gateway | HTTPS → HTTP |
| 6 | Gateway | Security validation | RELAY_KEY, path blocking |
| 7 | Gateway | Atomic write | `bridge/inbox/NOTIFY/{wo_id}_notify.json` |
| 8 | Gateway | Return success | `{ok: true, wo_id, queued_file}` |

**Duration:** ~100-500ms (network + processing)

---

### **Phase 2: Worker Processing**

| Step | Component | Action | Data |
|------|-----------|--------|------|
| 9 | Worker | Poll directory (5s interval) | Find `*.json` files |
| 10 | Worker | Stale check | File age < 24h? |
| 11 | Worker | Read JSON | Extract telegram config |
| 12 | Worker | Resolve chat_id | `resolve_chat_id(chat_name)` |
| 13 | Worker | Resolve token | `resolve_bot_token(chat_name)` |
| 14 | Worker | Send Telegram | POST to Telegram API |
| 15 | Telegram API | Process & deliver | HTTP 200 OK |
| 16 | Worker | Log metrics | JSONL entry |
| 17 | Worker | Move file | `processed/` or `failed/` |

**Duration:** ~1-5 seconds (polling + API call)

---

## 🔍 **ERROR PATHS**

### **Path A: Stale Notification**

```
Worker → Stale Check (>24h) → Log (skipped, stale) → Move to failed/_stale.json
```

### **Path B: Missing Config**

```
Worker → Read JSON → No telegram config → Log (skipped, no_config) → Move to processed/
```

### **Path C: API Failure**

```
Worker → Send Telegram → HTTP 429/500 → Retry (3x) → All fail → Log (failed) → Move to failed/
```

### **Path D: Missing Env Vars**

```
Worker Startup → Check env vars → Missing token/chat_id → Exit with error
```

---

## 📈 **METRICS & MONITORING**

### **Success Metrics:**

- ✅ Notification queued: Gateway returns `{ok: true}`
- ✅ File created: `bridge/inbox/NOTIFY/{wo_id}_notify.json` exists
- ✅ Worker processed: File moved to `processed/`
- ✅ Telegram delivered: HTTP 200 from API
- ✅ Metrics logged: Entry in `notify_worker.jsonl`

### **Failure Metrics:**

- ❌ Gateway error: HTTP 4xx/5xx response
- ❌ Stale notification: Moved to `failed/_stale.json`
- ❌ API failure: Moved to `failed/`, logged with reason
- ❌ Missing config: Moved to `processed/`, logged as skipped

---

## 🧪 **TESTING CHECKLIST**

### **End-to-End Test:**

- [ ] Create notification file manually in `NOTIFY/`
- [ ] Verify worker picks it up within 10 seconds
- [ ] Verify Telegram message received
- [ ] Verify file moved to `processed/`
- [ ] Verify log entry created

### **Integration Test:**

- [ ] Opal → POST /api/notify → Verify file created
- [ ] Wait for worker → Verify Telegram sent
- [ ] Check logs → Verify metrics entry

### **Error Test:**

- [ ] Stale file (>24h) → Verify skipped
- [ ] Missing telegram config → Verify skipped
- [ ] Invalid chat name → Verify failed
- [ ] Missing env vars → Verify startup guard exits

---

## 📁 **FILE LOCATIONS**

| Component | File/Directory | Purpose |
|-----------|----------------|---------|
| **Gateway** | `apps/opal_gateway/gateway.py` | HTTP API endpoint |
| **Worker** | `apps/opal_gateway/notify_worker.zsh` | Background processor |
| **LaunchAgent** | `~/Library/LaunchAgents/com.02luka.notify.worker.plist` | Auto-start |
| **Test Script** | `apps/opal_gateway/test_notify_worker.zsh` | Test suite |
| **Queue** | `bridge/inbox/NOTIFY/` | Notification files |
| **Processed** | `bridge/processed/NOTIFY/` | Successfully sent |
| **Failed** | `bridge/failed/NOTIFY/` | Failed/stale files |
| **Logs** | `g/telemetry/notify_worker.jsonl` | Metrics log |
| **Worker Logs** | `logs/notify_worker.{stdout,stderr}.log` | Worker output |

---

## 🎯 **STATUS SUMMARY**

| Component | Status | Notes |
|-----------|--------|-------|
| **Gateway** | ✅ Production Ready | v1.1.0, all security patches |
| **Worker** | ✅ Production Ready | v1.0.0, spec compliant |
| **LaunchAgent** | ✅ Created | Ready to load |
| **Test Script** | ✅ Created | Ready to run |
| **Opal Integration** | ⚠️ Pending | Needs Opal node configuration |
| **E2E Testing** | ⚠️ Pending | Needs manual verification |
| **LAC Integration** | ⚠️ Future | State file writing (Phase 3) |

**Overall:** ✅ **CORE SYSTEM READY** - Pending integration testing

---

**End of Flow Diagram**
