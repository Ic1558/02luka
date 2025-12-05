# Opal Configuration Guide - Notification System v1.0

**Date:** 2025-12-05  
**Purpose:** Step-by-step guide to configure Opal app for notification integration  
**Estimated Time:** 10-15 minutes

---

## 📋 **PREREQUISITES**

Before starting, ensure:

- [ ] Gateway is running on Mac Mini (`apps/opal_gateway/gateway.py`)
- [ ] Cloudflare Tunnel configured and active
- [ ] Gateway accessible via `https://gateway.theedges.work` (or your domain)
- [ ] `RELAY_KEY` configured in `.env.local` (optional but recommended)

**Verify Gateway:**
```bash
curl https://gateway.theedges.work/ping
# Expected: {"status": "ok", "message": "pong"}
```

---

## 🔧 **STEP 1: ADD NOTIFICATION NODE**

### **1.1: Locate Your Flow**

In Opal app, find your existing Work Order flow. It should have:

1. **User Input** node
2. **System Data Generator** node
3. **Generate JSON Work Order** node (AI prompt)
4. **Send to 02luka Gateway** node (HTTP POST to `/api/wo`)

### **1.2: Insert Notification Node**

**Position:** Between "Generate JSON Work Order" and "Send to 02luka Gateway"

**Action:**
1. Click on the connection between "Generate JSON Work Order" and "Send to 02luka Gateway"
2. Add new node: **"AI Prompt"** or **"Text Generation"**
3. Name it: **"Generate Notification Payload"**

---

## 📝 **STEP 2: CONFIGURE NOTIFICATION NODE**

### **2.1: Copy AI Prompt**

Open `OPAL_NOTIFY_NODE_PROMPT.md` and copy the entire prompt from the **"AI PROMPT"** section.

**Or use this prompt directly:**

```
You are an expert in generating notification payloads for the 02luka notification system.

Your task is to create a JSON notification payload based on Work Order data and user preferences.

## Input Data Available:
- Work Order JSON (from previous node)
- User notification preferences (if any)
- Work Order status (if available)

## Output Format:
Generate a JSON object with the following structure:

{
  "wo_id": "<work_order_id_from_input>",
  "telegram": {
    "chat": "<chat_name>",
    "text": "<formatted_message>",
    "meta": {
      "wo_id": "<work_order_id>",
      "lane": "<lane_name>",
      "status": "<status_value>"
    }
  },
  "line": null
}

## Chat Name Options:
- "boss_private" - For personal/boss notifications
- "ops" - For operations/group notifications  
- "general" - For general notifications
- Default: "boss_private"

## Message Format Guidelines:
1. Start with an emoji or status indicator (✅, ⚠️, ❌, 🔔, etc.)
2. Include Work Order ID prominently
3. Include key information: status, lane, app_mode, objective summary
4. Keep message concise but informative (max 2000 characters for Telegram)
5. Use Markdown formatting for readability:
   - **Bold** for important items
   - `Code` for IDs/technical terms
   - Line breaks for readability

## Example Output:

{
  "wo_id": "WO-20251205-EXP-0001",
  "telegram": {
    "chat": "boss_private",
    "text": "✅ Work Order Completed\n\n**WO:** `WO-20251205-EXP-0001`\n**Mode:** expense\n**Status:** DEV_COMPLETED\n**Lane:** dev_oss\n\nObjective: Process expense entry for lunch receipt\n\nCompleted at: 2025-12-05T06:45:12Z",
    "meta": {
      "wo_id": "WO-20251205-EXP-0001",
      "lane": "dev_oss",
      "status": "DEV_COMPLETED"
    }
  },
  "line": null
}

## Rules:
- Always include wo_id at the top level
- Always set "line" to null (LINE support deferred to v1.1)
- Use appropriate chat name based on context (boss_private for personal, ops for group)
- Format text with Markdown for Telegram
- Include meta object with wo_id, lane, and status
- Keep message under 2000 characters

Generate the notification payload now based on the Work Order data provided.
```

### **2.2: Configure Node Input**

**Input Connection:**
- Connect **"Generate Notification Payload"** node to receive output from **"Generate JSON Work Order"** node
- The input should be the Work Order JSON object

**In Opal, this might be:**
- Variable: `{{work_order_json}}` or `{{previous_node_output}}`
- Format: JSON object

---

## 🔗 **STEP 3: CONFIGURE HTTP NODE FOR NOTIFICATION**

### **3.1: Update Existing HTTP Node (or Create New)**

You have two options:

**Option A: Add Separate Notification Endpoint**
- Create new HTTP node: **"Send Notification to 02luka"**
- Configure POST to `/api/notify`

**Option B: Send Both (WO + Notification)**
- Keep existing "Send to 02luka Gateway" for `/api/wo`
- Add new HTTP node for `/api/notify` after notification payload is generated

### **3.2: Configure HTTP Request**

**Node Type:** HTTP Request / API Call

**Configuration:**

| Field | Value |
|-------|-------|
| **Name** | `Send Notification to 02luka` |
| **Method** | `POST` |
| **URL** | `https://gateway.theedges.work/api/notify` |

**Headers:**
```
Content-Type: application/json
X-Relay-Key: YOUR_RELAY_KEY_HERE
```

**Note:** If `RELAY_KEY` is not set in Gateway, you can omit the `X-Relay-Key` header for local testing.

**Body:**
- Use output from **"Generate Notification Payload"** node
- Format: JSON
- Variable: `{{notification_payload}}` or `{{previous_node_output}}`

### **3.3: Connect Nodes**

**Flow should now be:**

```
User Input
  ↓
System Data Generator
  ↓
Generate JSON Work Order
  ↓
Generate Notification Payload  ← NEW NODE
  ↓
Send Notification to 02luka    ← NEW HTTP NODE (POST /api/notify)
  ↓
Send to 02luka Gateway          ← EXISTING (POST /api/wo)
  ↓
Notification Preview (optional)
```

---

## 🎯 **STEP 4: CUSTOMIZE CHAT SELECTION (OPTIONAL)**

### **4.1: Add Chat Selection Logic**

You can customize the prompt to automatically select chat based on Work Order properties.

**Add to prompt (after "Chat Name Options" section):**

```
## Chat Selection Logic:
Select chat name based on:
- If app_mode is "ops" or lane is "ops" → use "ops"
- If priority is "high" → use "boss_private"
- If app_mode is "expense" or "trade" → use "boss_private"
- Otherwise → use "boss_private"
```

### **4.2: Example Customization**

For more complex logic, you can add conditional statements in Opal:

```
{% if work_order.app_mode == "ops" or work_order.lane == "ops" %}
  "chat": "ops"
{% elif work_order.priority == "high" %}
  "chat": "boss_private"
{% else %}
  "chat": "boss_private"
{% endif %}
```

---

## ✅ **STEP 5: VERIFY CONFIGURATION**

### **5.1: Test Flow in Opal**

1. **Create Test Work Order:**
   - Objective: "Test notification integration"
   - App Mode: `expense`
   - Priority: `high`

2. **Run Flow:**
   - Execute the flow
   - Check each node output

3. **Verify Notification Payload:**
   - Check "Generate Notification Payload" node output
   - Should be valid JSON with `wo_id`, `telegram`, `line: null`

4. **Verify HTTP Response:**
   - Check "Send Notification to 02luka" node response
   - Should return: `{"ok": true, "wo_id": "...", "queued_file": "..."}`

### **5.2: Verify on Mac Mini**

**Check Gateway Logs:**
```bash
tail -f ~/02luka/logs/gateway.log
# Should show: [RECEIVED] notification request
```

**Check Notification File:**
```bash
ls -la ~/02luka/bridge/inbox/NOTIFY/
# Should see new notification file
```

**Wait for Worker:**
```bash
# Wait 15 seconds
sleep 15

# Check processed
ls ~/02luka/bridge/processed/NOTIFY/
# Should see processed file

# Check Telegram (should receive message)
```

---

## 🔍 **TROUBLESHOOTING**

### **Issue: Notification Payload Not Generated**

**Check:**
- Verify AI prompt is correctly pasted
- Verify input connection from Work Order node
- Check node output for errors

**Fix:**
- Re-copy prompt from `OPAL_NOTIFY_NODE_PROMPT.md`
- Verify Work Order JSON structure matches expected format

### **Issue: HTTP Request Fails**

**Check:**
- Verify Gateway URL is correct
- Verify Cloudflare Tunnel is active
- Check Gateway logs for errors

**Fix:**
```bash
# Test Gateway manually
curl -X POST https://gateway.theedges.work/api/notify \
  -H "Content-Type: application/json" \
  -d '{"wo_id":"TEST","telegram":{"chat":"boss_private","text":"Test"}}'
```

### **Issue: Telegram Not Received**

**Check:**
- Verify worker is running
- Check worker logs
- Verify Telegram env vars in `.env.local`

**Fix:**
```bash
# Check worker status
ps aux | grep notify_worker.zsh

# Check logs
tail -f ~/02luka/logs/notify_worker.stdout.log
```

---

## 📊 **CONFIGURATION CHECKLIST**

After configuration, verify:

- [ ] Notification node added to flow
- [ ] AI prompt configured correctly
- [ ] HTTP node configured for `/api/notify`
- [ ] Headers include `Content-Type: application/json`
- [ ] Headers include `X-Relay-Key` (if configured)
- [ ] Node connections correct (flow sequence)
- [ ] Test flow executed successfully
- [ ] Gateway received notification request
- [ ] Worker processed notification
- [ ] Telegram message received

---

## 🎯 **NEXT STEPS**

After configuration is complete:

1. **Run Integration Tests:**
   - See `INTEGRATION_TESTING_GUIDE.md`
   - Test end-to-end flow

2. **Monitor:**
   - Watch Gateway logs
   - Watch worker logs
   - Check Telegram for messages

3. **Optimize:**
   - Customize chat selection logic
   - Adjust message formatting
   - Add notification preview node (optional)

---

**End of Opal Configuration Guide**
