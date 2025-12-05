# Opal Configuration - Step-by-Step Setup

**Date:** 2025-12-05  
**Purpose:** Complete setup guide for Opal App notification integration  
**Status:** Ready to Configure

---

## 📋 **PREREQUISITES**

Before configuring Opal:
- ✅ Gateway running on `localhost:5001`
- ✅ Cloudflare Tunnel configured (optional, for production)
- ✅ `RELAY_KEY` set in `.env.local`

---

## 🔧 **STEP 1: Add Notification Node**

### **1.1 Open Your Opal Flow**

In Opal App, locate your existing Work Order flow:
- User Input node
- Generate JSON Work Order node
- Send to 02luka Gateway node (for `/api/wo`)

### **1.2 Insert New Node**

**Position:** Between "Generate JSON Work Order" and "Send to 02luka Gateway"

**Node Type:** `AI Prompt` or `Text Generation`

**Node Name:** `Generate Notification Payload`

---

## 🤖 **STEP 2: Configure AI Prompt**

### **2.1 Copy Prompt**

Open: `~/02luka/apps/opal_gateway/OPAL_NOTIFY_NODE_PROMPT.md`

Copy the entire prompt from the `## 🤖 **AI PROMPT**` section.

### **2.2 Paste into Opal Node**

1. Select the "Generate Notification Payload" node
2. Paste the prompt into the node's prompt field
3. Set input variable: `{{work_order_json}}` (from previous node)

---

## 🔗 **STEP 3: Connect Nodes**

### **3.1 Input Connection**

Connect output from "Generate JSON Work Order" → Input of "Generate Notification Payload"

**Variable Name:** `work_order_json` (or whatever your WO node outputs)

### **3.2 Output Connection**

Connect output from "Generate Notification Payload" → Input of "Send to 02luka Gateway" (new endpoint)

**Variable Name:** `notification_payload`

---

## 🌐 **STEP 4: Configure Gateway HTTP Node**

### **4.1 Create New HTTP Node (or Modify Existing)**

**Node Type:** `HTTP Request` or `API Call`

**Node Name:** `Send Notification to 02luka`

### **4.2 Configure Endpoint**

| Field | Value |
|-------|-------|
| **Method** | `POST` |
| **URL** | `http://localhost:5001/api/notify` (local) or `https://gateway.theedges.work/api/notify` (production) |
| **Content-Type** | `application/json` |

### **4.3 Configure Headers**

Add header:
- **Name:** `X-Relay-Key`
- **Value:** `{{RELAY_KEY}}` (from Opal environment variables)

**OR** hardcode if Opal doesn't support env vars:
- **Value:** `YOUR_RELAY_KEY_FROM_ENV_LOCAL`

### **4.4 Configure Body**

**Body Type:** `JSON`

**Body Content:**
```json
{{notification_payload}}
```

This passes the entire notification payload from the AI node.

---

## ✅ **STEP 5: Verification**

### **5.1 Test Flow**

1. Run your Opal flow with a test Work Order
2. Check Gateway logs:
   ```bash
   tail -f ~/02luka/logs/gateway.log
   ```
3. Verify file created:
   ```bash
   ls -la ~/02luka/bridge/inbox/NOTIFY/
   ```
4. Wait 10 seconds, check processed:
   ```bash
   ls -la ~/02luka/bridge/processed/NOTIFY/
   ```
5. Check Telegram for message

### **5.2 Expected Flow**

```
User Input
  ↓
Generate JSON Work Order
  ↓
Generate Notification Payload  ← NEW
  ↓
Send Notification to 02luka    ← NEW
  ↓
Notification Preview (optional)
```

---

## 🎯 **STEP 6: Customization (Optional)**

### **6.1 Chat Selection Logic**

Modify the AI prompt to select chat based on Work Order properties:

**Add to prompt:**
```
Select chat name based on:
- If app_mode is "ops" or lane is "ops" → use "ops"
- If priority is "high" → use "boss_private"
- Otherwise → use "boss_private"
```

### **6.2 Message Formatting**

Customize the message format in the prompt to match your preferences.

---

## 🔍 **TROUBLESHOOTING**

### **Issue: Notification Not Generated**

**Check:**
- AI prompt is correctly pasted
- Input variable name matches previous node output
- Opal AI model has access to Work Order JSON

**Fix:**
- Verify node connections
- Test prompt in Opal's AI playground

### **Issue: Gateway Returns 401**

**Check:**
- `X-Relay-Key` header is set
- Header value matches `.env.local` `RELAY_KEY`

**Fix:**
- Verify header name is exactly `X-Relay-Key`
- Check `.env.local` for correct value

### **Issue: File Created But No Telegram**

**Check:**
- Worker is running: `ps aux | grep notify_worker`
- Worker logs: `tail -f ~/02luka/logs/notify_worker.stdout.log`

**Fix:**
- Start worker: `launchctl load ~/Library/LaunchAgents/com.02luka.notify.worker.plist`

---

## 📝 **QUICK REFERENCE**

**Files:**
- Prompt: `~/02luka/apps/opal_gateway/OPAL_NOTIFY_NODE_PROMPT.md`
- Flow Diagram: `~/02luka/apps/opal_gateway/NOTIFICATION_FLOW_DIAGRAM.md`
- Testing Guide: `~/02luka/apps/opal_gateway/INTEGRATION_TESTING_GUIDE.md`

**Endpoints:**
- Local: `http://localhost:5001/api/notify`
- Production: `https://gateway.theedges.work/api/notify`

**Directories:**
- Queue: `~/02luka/bridge/inbox/NOTIFY/`
- Processed: `~/02luka/bridge/processed/NOTIFY/`
- Failed: `~/02luka/bridge/failed/NOTIFY/`

---

**End of Opal Setup Guide**
