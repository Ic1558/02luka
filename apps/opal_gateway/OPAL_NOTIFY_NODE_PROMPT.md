# Opal Node Prompt: Queue Notification

**Purpose:** AI prompt for Opal "Generate Notification Payload" node  
**Version:** 1.0  
**Date:** 2025-12-05

---

## 📋 **NODE CONFIGURATION**

**Node Type:** AI Prompt / Text Generation  
**Node Name:** `Generate Notification Payload`  
**Position:** After "Generate JSON Work Order" node, before "Send to 02luka Gateway" node

---

## 🤖 **AI PROMPT**

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

---

## 🔗 **NODE CONNECTIONS**

**Input:**
- `Work Order JSON` (from "Generate JSON Work Order" node)

**Output:**
- `Notification Payload JSON` → Connect to "Send to 02luka Gateway" node (POST /api/notify)

---

## 📝 **USAGE IN OPAL FLOW**

### **Flow Sequence:**

1. **User Input** → Captures objective, mode, files
2. **System Data Generator** → UUID, timestamp
3. **Generate JSON Work Order** → Creates WO JSON
4. **⭐ Generate Notification Payload** ← **THIS NODE**
5. **Send to 02luka Gateway** → POST /api/notify
6. **Notification Preview** → Display confirmation

---

## 🎯 **CUSTOMIZATION OPTIONS**

### **Chat Selection Logic:**

You can customize the prompt to select chat based on:

- **App Mode:**
  - `expense`, `trade` → `boss_private`
  - `ops`, `monitoring` → `ops`
  - Default → `boss_private`

- **Priority:**
  - `high` → `boss_private`
  - `medium`, `low` → `ops` or `general`

- **Lane:**
  - `dev_oss`, `trader` → `boss_private`
  - `ops`, `monitoring` → `ops`

**Example Prompt Addition:**
```
Select chat name based on:
- If app_mode is "ops" or lane is "ops" → use "ops"
- If priority is "high" → use "boss_private"
- Otherwise → use "boss_private"
```

---

## ✅ **VERIFICATION**

After generating the payload, verify:
- ✅ `wo_id` matches Work Order ID
- ✅ `telegram.chat` is one of: "boss_private", "ops", "general"
- ✅ `telegram.text` is formatted and under 2000 chars
- ✅ `telegram.meta` contains wo_id, lane, status
- ✅ `line` is set to `null`

---

**End of Prompt Guide**
