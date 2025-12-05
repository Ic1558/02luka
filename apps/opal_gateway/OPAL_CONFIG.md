# Opal App Configuration Guide

## Part 2: Opal Webhook Setup

This document contains the complete configuration for connecting your Opal App to the 02luka gateway.

---

## 📋 Prerequisites

Before configuring Opal, ensure:

1. ✅ **Gateway is running** on Mac Mini (Part 1 complete)
2. ✅ **Cloudflare Tunnel is configured** and exposes the gateway
3. ✅ **Webhook URL is ready** (e.g., `https://gateway.theedges.work/api/wo`)

---

## 🔧 Opal Flow Configuration

### Step 1: Locate Your Flow

In your Opal App flow, you should have these nodes in sequence:

1. **User Input** (captures objective, mode, files, etc.)
2. **System Data Generator** (UUID, timestamp)
3. **Generate JSON Work Order** (the AI prompt node)
4. **⭐ NEW: Send to 02luka** (the webhook node)

---

### Step 2: Add the Webhook Node

**After** the "Generate JSON Work Order" node, add:

**Node Type:** `HTTP Request` or `API Call`

#### Configuration:

| Field | Value |
|-------|-------|
| **Name** | `Send to 02luka Gateway` |
| **Method** | `POST` |
| **URL** | `https://gateway.theedges.work/api/wo` |

#### Headers:

```
Content-Type: application/json
X-Relay-Key: YOUR_RELAY_KEY_FROM_ENV_LOCAL
```

⚠️ **Important:** Replace `YOUR_RELAY_KEY_FROM_ENV_LOCAL` with the actual value from your Mac Mini's `/Users/icmini/02luka/.env.local` file.

To get your relay key:
```bash
# On Mac Mini, run:
grep RELAY_KEY ~/02luka/.env.local
```

#### Body:

**Select:** Output from previous node "Generate JSON Work Order"

Or if using variable mapping:
```
{{GenerateJSONWorkOrder.output}}
```

#### Advanced Settings:

- **Timeout:** `10000` ms (10 seconds)
- **Retry on Failure:** `Yes` (2-3 retries recommended)
- **Success Condition:** HTTP Status `200-299`

---

### Step 3: Handle Response

Add a success/failure handler after the webhook:

#### On Success (HTTP 200):

**Display to User:**
```
✅ Work Order submitted successfully!

WO ID: {{SendTo02luka.response.wo_id}}
Status: {{SendTo02luka.response.status}}
Message: {{SendTo02luka.response.message}}

Your request is being processed by 02luka agents.
```

#### On Failure:

**Display to User:**
```
❌ Failed to submit Work Order

Please try again or contact support.
Error: {{SendTo02luka.error}}
```

---

## 🎨 Updated Opal JSON Generator Prompt

Replace your current "Generate JSON Work Order" node prompt with this:

```text
You are the 02luka Work Order Generator (Advanced Bridge Edition).

--------------------------------------------------------
SYSTEM DATA (Strict)
--------------------------------------------------------
{{GenerateUUIDsAndTimestamp}}

--------------------------------------------------------
USER INPUTS
--------------------------------------------------------
- App Mode: {{AppMode}}
- Lane: {{LaneSelection}}
- Priority: {{Priority}}
- Objective: {{Objective}}

[Context Data]
- Expense Details: {{ExpenseDescription}} {{ExpenseAmount}} {{ExpenseNote}}
- Project: {{ProjectName}} (or {{ExpenseProject}})
- Files: {{UploadedFiles}} (Receipts, Charts, PDFs, Site Photos)
- Estimation Focus: {{EstimationFocus}}
- Progress Text: {{ProgressUpdateText}}

--------------------------------------------------------
LOGIC ENGINE
--------------------------------------------------------
1. **Analyze Intent**:
   - Keywords "chart", "trend", "buy/sell", "SET50" → Mode: **Trade**
   - Keywords "open app", "click", "mouse", "automate" → Mode: **GuiAuto**
   - Keywords "antigravity", "core code", "atg" → Mode: **DevTask**
   - Keywords "notify", "telegram", "line" → Set **Notify Flags**

2. **Map to AP/IO v3.1 Schema**:
   - Ensure ledger_id comes from System Data
   - Map files to correct attachments category
   - Set execution mode based on app_mode

--------------------------------------------------------
JSON OUTPUT (Strict - Return ONLY this JSON)
--------------------------------------------------------
{
  "wo_id": "WO-{{AppMode}}-{{WO_SUFFIX_FROM_SYSTEM_DATA}}",
  "app_mode": "<Expense|Trade|GuiAuto|Progress|DevTask|Estimation>",
  "objective": "<Summary of user intent>",
  "priority": "{{Priority}}",
  "lane": "{{LaneSelection}}",
  "project_name": "{{ProjectName}}",
  "requires_clc": false,

  "notify": {
    "telegram": <true if keywords: telegram, notify, alert>,
    "line": <true if keywords: line, notify>
  },

  "execution": {
    "mode": "<none|gui_automation|atg_pipeline|trade_analysis>",
    "target_app": "<Excel|TradingView|Browser|null>",
    "target_system": "<antigravity|null>",
    "requires_hybrid_agent": <true if mode=gui_automation>
  },

  "trade_context": {
    "market": "<inferred: SET50|Crypto|Forex|null>",
    "timeframe": "<inferred: M5|M15|H1|H4|D1|null>",
    "chart_screenshots": ["<List filenames from UploadedFiles if images>"]
  },

  "expense": {
    "date": "{{ExpenseDate}}",
    "account": "{{ExpenseAccount}}",
    "pay_method": "{{ExpensePay}}",
    "description": "{{ExpenseDescription}}",
    "amount": {{ExpenseAmount}},
    "project": "{{ExpenseProject}}",
    "note": "{{ExpenseNote}}"
  },

  "progress": {
     "update_text": "{{ProgressUpdateText}}",
     "site_photos": ["<List filenames from SitePhotos>"]
  },

  "attachments": {
    "all_files": ["<List ALL uploaded filenames here>"]
  },

  "apio_log": {
    "ledger_id": "{{LEDGER_ID_FROM_SYSTEM_DATA}}",
    "correlation_id": "{{CORRELATION_ID_FROM_SYSTEM_DATA}}",
    "timestamp": "{{TIMESTAMP_FROM_SYSTEM_DATA}}",
    "agent": "Opal_App_Bridge",
    "event": "work_order_bridged"
  }
}
```

**Notes:**
- Replace `{{VariableName}}` with your actual Opal variable names
- The `<>` placeholders should be filled by the AI based on user input
- Ensure System Data node provides: `LEDGER_ID`, `CORRELATION_ID`, `TIMESTAMP`, `WO_SUFFIX`

---

## 🧪 Testing the Integration

### Test 1: Simple Trade Request

**User Input in Opal:**
```
App Mode: Trade
Objective: วิเคราะห์กราฟ SET50 H1 ส่ง Telegram
Priority: medium
Lane: trader
[Upload: chart.jpg]
```

**Expected Result:**
1. Opal generates JSON with `app_mode: "Trade"`
2. Webhook sends to `gateway.theedges.work`
3. Gateway saves to `bridge/inbox/LIAM/WO-Trade-XXX.json`
4. You receive success message with WO ID

**Verify:**
```bash
# On Mac Mini:
ls -lha ~/02luka/bridge/inbox/LIAM/WO-Trade-*
cat ~/02luka/bridge/inbox/LIAM/WO-Trade-*.json | jq
```

### Test 2: Expense Entry

**User Input:**
```
App Mode: Expense
Description: ค่าอาหาร
Amount: 350
Pay Method: Cash
[Upload: receipt.jpg]
```

**Verify JSON includes:**
- `app_mode: "Expense"`
- `expense.amount: 350`
- `attachments.all_files: ["receipt.jpg"]`

---

## 🔐 Security Best Practices

1. **Never hardcode RELAY_KEY in Opal flows**
   - Use Opal's secure variables feature
   - Or configure via Opal environment settings

2. **Use HTTPS only**
   - Cloudflare Tunnel provides automatic HTTPS
   - Never expose `http://localhost:5000` directly

3. **Rotate relay keys periodically**
   - Update `.env.local` on Mac Mini
   - Update Opal configuration
   - Restart gateway

---

## 📊 Monitoring & Debugging

### Check Gateway Logs

```bash
# If running in foreground:
# Logs appear in terminal

# If running as LaunchAgent:
tail -f ~/02luka/logs/opal_gateway.log
tail -f ~/02luka/logs/opal_gateway.err
```

### Check Gateway Stats

```bash
curl https://gateway.theedges.work/stats
```

Expected response:
```json
{
  "status": "operational",
  "inbox_path": "/Users/icmini/02luka/bridge/inbox/LIAM",
  "pending_work_orders": 0,
  "timestamp": "2025-12-05T04:30:00.123Z"
}
```

### Common Issues

| Issue | Solution |
|-------|----------|
| **401 Unauthorized** | Check `X-Relay-Key` header matches `.env.local` |
| **Connection refused** | Ensure gateway is running: `lsof -i :5000` |
| **Timeout** | Check Cloudflare Tunnel status |
| **Files not in inbox** | Check gateway logs for errors |

---

## 🎯 Next Steps After Configuration

1. **Test with simple work order** (Trade or Expense)
2. **Verify JSON appears in bridge/inbox/LIAM/**
3. **Monitor agent processing** (check if Liam picks it up)
4. **Test notifications** (Telegram/LINE integration)
5. **Test file attachments** (charts, receipts, photos)
6. **Scale to production** (enable LaunchAgent auto-start)

---

## 📞 Support

If you encounter issues:

1. Check gateway logs
2. Verify Cloudflare Tunnel is running
3. Test direct to `localhost:5000` first
4. Review Opal webhook response codes

---

**Configuration Version:** 1.0  
**Compatible with:** Opal App v2.0+, 02luka Bridge v3.0  
**Last Updated:** 2025-12-05
