# Integration Testing Guide - Notification System v1.0

**Date:** 2025-12-05  
**Purpose:** Step-by-step manual testing guide for complete end-to-end verification  
**Status:** Ready to Execute

---

## 🎯 **TESTING OBJECTIVES**

Verify complete flow:
1. ✅ Gateway receives notification request
2. ✅ Worker processes notification file
3. ✅ Telegram message delivered
4. ✅ Files moved correctly
5. ✅ Logs recorded properly

---

## 📋 **PREREQUISITES**

### **1. Environment Check**

```bash
# Verify .env.local exists and has required vars
cd ~/02luka
source .env.local
echo "Token: ${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:0:10}..."
echo "Chat ID: ${TELEGRAM_SYSTEM_ALERT_CHAT_ID}"
```

**Expected:** Both variables should have values

---

### **2. Gateway Status**

```bash
# Check if gateway is running
curl -s http://localhost:5001/ | jq .
```

**Expected:** `{"status": "ok", "service": "02luka Gateway"}`

**If not running:**
```bash
cd ~/02luka/apps/opal_gateway
python gateway.py &
# Or use: ./start_gateway.sh
```

---

### **3. Worker Status**

```bash
# Check if worker is running
ps aux | grep notify_worker.zsh | grep -v grep
```

**Expected:** Process should be running

**If not running:**
```bash
# Option 1: Manual start (for testing)
~/02luka/apps/opal_gateway/notify_worker.zsh &

# Option 2: LaunchAgent (production)
launchctl load ~/Library/LaunchAgents/com.02luka.notify.worker.plist
```

**Verify worker is active:**
```bash
tail -f ~/02luka/logs/notify_worker.stdout.log
```

---

## 🧪 **TEST 1: Manual Notification File Creation**

**Purpose:** Test worker processing without gateway

### **Step 1: Create Test File**

```bash
cd ~/02luka
mkdir -p bridge/inbox/NOTIFY

cat > bridge/inbox/NOTIFY/WO-TEST-MANUAL-$(date +%s)_notify.json <<'EOF'
{
  "wo_id": "WO-TEST-MANUAL-001",
  "telegram": {
    "chat": "boss_private",
    "text": "🧪 Manual Integration Test\n\n**WO:** `WO-TEST-MANUAL-001`\n**Test:** Manual file creation\n**Time:** $(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "meta": {
      "wo_id": "WO-TEST-MANUAL-001",
      "status": "TEST",
      "lane": "integration_test"
    }
  },
  "line": null
}
EOF
```

### **Step 2: Wait for Processing**

```bash
# Wait 10 seconds
sleep 10

# Check if file moved
ls -la bridge/processed/NOTIFY/ | grep WO-TEST-MANUAL
ls -la bridge/failed/NOTIFY/ | grep WO-TEST-MANUAL
```

**Expected:** File should be in `processed/` directory

### **Step 3: Verify Telegram**

Check your Telegram chat for the test message.

### **Step 4: Check Logs**

```bash
tail -n 5 ~/02luka/g/telemetry/notify_worker.jsonl | jq .
```

**Expected:** Entry with `"result": "success"`, `"wo_id": "WO-TEST-MANUAL-001"`

---

## 🧪 **TEST 2: Gateway → Worker Flow**

**Purpose:** Test complete flow from HTTP API

### **Step 1: Send Notification via Gateway**

```bash
# Get RELAY_KEY from .env.local
RELAY_KEY=$(grep RELAY_KEY ~/02luka/.env.local | cut -d'=' -f2 | tr -d '"')

# Send notification
curl -X POST http://localhost:5001/api/notify \
  -H "Content-Type: application/json" \
  -H "X-Relay-Key: $RELAY_KEY" \
  -d '{
    "wo_id": "WO-TEST-GATEWAY-001",
    "telegram": {
      "chat": "boss_private",
      "text": "🧪 Gateway Integration Test\n\n**WO:** `WO-TEST-GATEWAY-001`\n**Source:** HTTP API\n**Time:** '$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
      "meta": {
        "wo_id": "WO-TEST-GATEWAY-001",
        "status": "TEST",
        "lane": "gateway_test"
      }
    },
    "line": null
  }' | jq .
```

**Expected Response:**
```json
{
  "ok": true,
  "wo_id": "WO-TEST-GATEWAY-001",
  "queued_file": "bridge/inbox/NOTIFY/WO-TEST-GATEWAY-001_notify.json",
  "timestamp": "..."
}
```

### **Step 2: Verify File Created**

```bash
# Check inbox
ls -la ~/02luka/bridge/inbox/NOTIFY/ | grep WO-TEST-GATEWAY
```

**Expected:** File should exist

### **Step 3: Wait for Worker**

```bash
sleep 10
ls -la ~/02luka/bridge/processed/NOTIFY/ | grep WO-TEST-GATEWAY
```

**Expected:** File moved to `processed/`

### **Step 4: Verify Telegram**

Check Telegram for the message.

### **Step 5: Check Gateway Logs**

```bash
tail -n 10 ~/02luka/logs/gateway.log | grep WO-TEST-GATEWAY
```

**Expected:** Log entry showing file creation

---

## 🧪 **TEST 3: Error Handling**

### **Test 3.1: Missing RELAY_KEY**

```bash
curl -X POST http://localhost:5001/api/notify \
  -H "Content-Type: application/json" \
  -d '{"wo_id": "WO-TEST-ERROR-001"}' | jq .
```

**Expected:** `{"ok": false, "error": "unauthorized", ...}` with HTTP 401

### **Test 3.2: Invalid Chat Name**

```bash
RELAY_KEY=$(grep RELAY_KEY ~/02luka/.env.local | cut -d'=' -f2 | tr -d '"')

cat > ~/02luka/bridge/inbox/NOTIFY/WO-TEST-INVALID-CHAT_notify.json <<'EOF'
{
  "wo_id": "WO-TEST-INVALID-CHAT",
  "telegram": {
    "chat": "invalid_chat_name",
    "text": "Test"
  }
}
EOF

sleep 10

# Check failed directory
ls -la ~/02luka/bridge/failed/NOTIFY/ | grep WO-TEST-INVALID
```

**Expected:** File moved to `failed/` with error logged

### **Test 3.3: Stale Notification**

```bash
# Create file with old timestamp
cat > ~/02luka/bridge/inbox/NOTIFY/WO-TEST-STALE_notify.json <<'EOF'
{
  "wo_id": "WO-TEST-STALE",
  "telegram": {
    "chat": "boss_private",
    "text": "Stale test"
  }
}
EOF

# Make file 25 hours old (macOS)
touch -t $(date -v-25H +%Y%m%d%H%M.%S) ~/02luka/bridge/inbox/NOTIFY/WO-TEST-STALE_notify.json

sleep 10

# Check failed directory
ls -la ~/02luka/bridge/failed/NOTIFY/ | grep WO-TEST-STALE
```

**Expected:** File moved to `failed/` with `_stale` suffix

---

## 🧪 **TEST 4: Multiple Notifications**

**Purpose:** Test worker handles multiple files correctly

```bash
# Create 3 test files
for i in {1..3}; do
  cat > ~/02luka/bridge/inbox/NOTIFY/WO-TEST-BATCH-$i_notify.json <<EOF
{
  "wo_id": "WO-TEST-BATCH-$i",
  "telegram": {
    "chat": "boss_private",
    "text": "🧪 Batch Test #$i\n\nWO: WO-TEST-BATCH-$i"
  }
}
EOF
done

# Wait for processing
sleep 15

# Verify all processed
ls -la ~/02luka/bridge/processed/NOTIFY/ | grep WO-TEST-BATCH | wc -l
```

**Expected:** All 3 files should be in `processed/`

---

## 📊 **VERIFICATION CHECKLIST**

After running all tests, verify:

- [ ] **Gateway:** All HTTP requests return correct responses
- [ ] **Worker:** All notification files processed
- [ ] **Telegram:** All test messages received
- [ ] **Files:** All files moved to correct directories
- [ ] **Logs:** All entries recorded in `notify_worker.jsonl`
- [ ] **Error Handling:** Invalid inputs handled gracefully
- [ ] **Stale Guard:** Old files skipped correctly

---

## 🔍 **TROUBLESHOOTING**

### **Worker Not Processing Files**

```bash
# Check worker logs
tail -f ~/02luka/logs/notify_worker.stderr.log

# Verify worker is running
ps aux | grep notify_worker

# Restart worker
pkill -f notify_worker.zsh
~/02luka/apps/opal_gateway/notify_worker.zsh &
```

### **Telegram Not Sending**

```bash
# Verify env vars
source ~/02luka/.env.local
echo "Token: ${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:0:20}..."
echo "Chat ID: ${TELEGRAM_SYSTEM_ALERT_CHAT_ID}"

# Test Telegram API directly
curl -X POST "https://api.telegram.org/bot${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_SYSTEM_ALERT_CHAT_ID}" \
  -d "text=Direct API Test"
```

### **Gateway Not Responding**

```bash
# Check if running
curl http://localhost:5001/

# Check logs
tail -f ~/02luka/logs/gateway.log

# Restart gateway
cd ~/02luka/apps/opal_gateway
pkill -f gateway.py
python gateway.py &
```

---

## ✅ **SUCCESS CRITERIA**

All tests pass when:
1. ✅ Gateway accepts and queues notifications
2. ✅ Worker processes files within 10 seconds
3. ✅ Telegram messages delivered successfully
4. ✅ Files moved to correct directories
5. ✅ Logs contain accurate entries
6. ✅ Error cases handled gracefully

---

**End of Integration Testing Guide**
