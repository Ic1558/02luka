# Feature Development Plan: Complete 02luka Notification System v1.0

**Feature:** Complete Notification System v1.0  
**Status:** ✅ **FINAL - Ready for Implementation**  
**Created:** 2025-12-05  
**Updated:** 2025-12-05 (Final polish)  
**Author:** CLS  
**Priority:** High

---

## 🎯 **V1.0 SCOPE - IMPORTANT**

**Notification System v1.0 = Telegram Only**

- ✅ **Telegram:** Fully implemented and tested
- ⏸️ **LINE:** Deferred to future phase (v1.1+)
- 📝 **Rationale:** Focus on one channel first, ensure stability, then expand

**Implementation Note:**
- Worker will process LINE config if present, but LINE API integration is not in v1.0 scope
- All v1.0 testing focuses on Telegram only
- LINE support will be added in future phase

---

## 🔧 **SPEC UPDATES (2025-12-05)**

**Critical additions based on Boss review:**

1. ✅ **Section 4: Telegram/Line Channel Mapping Rules**
   - Exact mapping table: `boss_private` → `TELEGRAM_SYSTEM_ALERT_CHAT_ID` (verified)
   - Fallback chain implementation
   - Token resolution pattern
   - Error handling for missing chat_id

2. ✅ **Section 5: State File → Notification Fallback Logic**
   - Fallback chain: Notification file → State file → WO file
   - Implementation functions with examples
   - Scenario table (all combinations)
   - Logging requirements

3. ✅ **Section 6: Worker Retry Rules**
   - Max 3 retries with exponential backoff (2s, 4s, 8s)
   - HTTP status code handling (retry vs no-retry)
   - Timeout configuration (10 seconds)
   - Failure handling (move to `failed/` directory)

**Impact:**
- Task 1.1 requirements updated (now includes all 3 features)
- Task 1.3 test cases expanded (channel mapping, retry, fallback tests)
- Task 3.1 updated (notify config preservation requirements)
- Estimated time increased: 3-4 hours (was 2-3 hours)

**Status:** ✅ **SPEC COMPLETE** - All gaps addressed, ready for implementation

---

## 📋 **EXECUTIVE SUMMARY**

### **Current State (What's DONE ✅)**

**Gateway Layer (Complete):**
- ✅ `apps/opal_gateway/gateway.py` v1.1.0 operational
- ✅ 6 endpoints: `/`, `/ping`, `/stats`, `/api/wo`, `/api/wo_status`, `/api/notify`
- ✅ Atomic file writes to `bridge/inbox/LIAM/` and `bridge/inbox/NOTIFY/`
- ✅ Security: RELAY_KEY, CloudStorage blocking, input validation
- ✅ Directory auto-creation: `bridge/inbox/LIAM/`, `bridge/inbox/NOTIFY/`, `followup/state/`

**What Gateway Does:**
- Receives Work Orders from Opal → writes `bridge/inbox/LIAM/{wo_id}.json`
- Receives notification requests → writes `bridge/inbox/NOTIFY/{wo_id}_notify.json`
- Reads state files → `followup/state/{wo_id}.json` (returns 404 if missing)

### **Gap Analysis (What's MISSING ❌)**

**Missing Components:**
1. ❌ **Notification Worker** - No background process reading `NOTIFY/` and sending Telegram/Line
2. ❌ **State File Writers** - LAC/Hybrid Agent/ATG not writing `followup/state/{wo_id}.json`
3. ❌ **End-to-End Flow** - No complete chain: Opal → Gateway → Worker → Notification → Status
4. ❌ **Cloudflare Tunnel** - Not verified/configured (mentioned as "next step")

**Current Reality:**
- Gateway queues notifications to files ✅
- Files sit in `bridge/inbox/NOTIFY/` with no consumer ❌
- `/api/wo_status` returns 404 because no state files exist ❌
- No actual Telegram/Line messages sent ❌

---

## 🎯 **FEATURE OBJECTIVES**

### **Primary Goal**
Complete the notification pipeline so that:
1. Work Orders flow from Opal → Gateway → LAC/Agent → State File
2. Notifications are queued → Worker processes → Telegram/Line sent
3. Status queries return actual state (not 404)
4. End-to-end flow is testable and operational

### **Success Criteria**
- ✅ Notification Worker running and processing `NOTIFY/` files
- ✅ At least 1 test notification sent via Telegram successfully
- ✅ State file format standardized and documented
- ✅ LAC/Hybrid Agent integration spec ready
- ✅ End-to-end test script passes

---

## 📐 **ARCHITECTURE DESIGN**

### **Complete Flow Diagram**

```
┌─────────────┐
│  Opal App  │
│  (Cloud)   │
└─────┬───────┘
      │ POST /api/wo
      │ (Work Order JSON)
      ▼
┌─────────────────────┐
│  Gateway (Flask)    │ ✅ EXISTS
│  localhost:5001     │
└─────┬───────────────┘
      │ Atomic Write
      ▼
┌─────────────────────┐
│ bridge/inbox/LIAM/  │ ✅ EXISTS
│ {wo_id}.json        │
└─────┬───────────────┘
      │ File Watcher / Agent
      ▼
┌─────────────────────┐
│ LAC / Hybrid Agent  │ ❌ MISSING
│ / ATG               │
└─────┬───────────────┘
      │ Process WO
      │ Write State
      ▼
┌─────────────────────┐
│ followup/state/     │ ❌ MISSING
│ {wo_id}.json        │
└─────┬───────────────┘
      │ Contains notify config
      ▼
┌─────────────────────┐
│ Gateway /api/notify │ ✅ EXISTS
│ OR Agent writes     │
└─────┬───────────────┘
      │ Atomic Write
      ▼
┌─────────────────────┐
│ bridge/inbox/       │ ✅ EXISTS
│ NOTIFY/             │
│ {wo_id}_notify.json │
└─────┬───────────────┘
      │ Worker Polls
      ▼
┌─────────────────────┐
│ Notification Worker │ ❌ MISSING
│ (zsh or Python)     │
└─────┬───────────────┘
      │ Send via API
      ▼
┌─────────────┬─────────────┐
│  Telegram   │    LINE     │
│  Bot API    │  Messaging  │
└─────────────┴─────────────┘
```

---

## 🔧 **COMPONENT SPECIFICATIONS**

### **1. Notification Worker**

**Purpose:** Background process that reads `bridge/inbox/NOTIFY/*.json` and sends notifications via Telegram/Line.

**Two Implementation Options:**

#### **Option A: ZSH Worker (Recommended for Quick Start)**

**File:** `apps/opal_gateway/notify_worker.zsh`

**Features:**
- Polls `bridge/inbox/NOTIFY/` every 5-10 seconds
- Uses existing `system_alert_send.zsh` for Telegram
- Moves processed files to `bridge/processed/NOTIFY/`
- Logs to `g/telemetry/notify_worker.jsonl`
- Handles errors gracefully (retry, skip, log)

**Dependencies:**
- `g/tools/system_alert_send.zsh` (exists ✅)
- `.env.local` with Telegram/Line tokens (exists ✅)

**Advantages:**
- Quick to implement (reuse existing tools)
- Consistent with 02luka shell script patterns
- Easy to debug (can run manually)

**Disadvantages:**
- Limited error handling compared to Python
- Harder to unit test

#### **Option B: Python Worker**

**File:** `apps/opal_gateway/notify_worker.py`

**Features:**
- Uses `requests` library for Telegram/Line API
- More robust error handling and retries
- JSONL logging with structured data
- Can be tested with pytest
- Better for future extensions (webhooks, etc.)

**Dependencies:**
- Python 3.12+
- `requests` library
- `.env.local` with tokens

**Advantages:**
- Better testability
- More maintainable for complex logic
- Easier to add features (rate limiting, batching, etc.)

**Disadvantages:**
- Requires Python environment setup
- More dependencies

**Recommendation:** Start with **Option A (ZSH)** for quick implementation, then migrate to Python if needed.

---

### **2. State File Format Specification**

**Purpose:** Standardize the format that LAC/Hybrid Agent/ATG must write to `followup/state/{wo_id}.json`.

**File:** `apps/opal_gateway/STATE_FILE_SPEC.md` (to be created)

**Schema:**

```json
{
  "wo_id": "WO-20251205-EXP-0001",
  "status": "DEV_COMPLETED",
  "lane": "dev_oss",
  "app_mode": "expense",
  "priority": "high",
  "objective": "Process expense entry for lunch receipt",
  "last_update": "2025-12-05T06:45:12Z",
  "notify": {
    "enable": true,
    "telegram": {
      "enable": true,
      "chat": "boss_private",
      "text": "✅ Work Order Completed\n\nWO: WO-20251205-EXP-0001\nMode: expense\nStatus: DEV_COMPLETED",
      "meta": {
        "wo_id": "WO-20251205-EXP-0001",
        "lane": "dev_oss",
        "status": "DEV_COMPLETED"
      }
    },
    "line": {
      "enable": false,
      "room": null
    }
  },
  "artifacts": [
    {
      "type": "file",
      "path": "g/reports/expense_20251205.json",
      "description": "Processed expense entry"
    }
  ],
  "execution_time_seconds": 12.5,
  "agent": "LAC",
  "version": "1.0"
}
```

**Required Fields:**
- `wo_id` (string) - Work Order ID
- `status` (string) - Current status (e.g., "DEV_COMPLETED", "QA_PENDING", "FAILED")
- `lane` (string) - Execution lane (e.g., "dev_oss", "trader", "expense")
- `app_mode` (string) - Application mode (e.g., "expense", "trade", "gui")
- `priority` (string) - Priority level (e.g., "high", "medium", "low")
- `objective` (string) - Work Order objective
- `last_update` (string) - ISO 8601 timestamp (UTC)
- `notify` (object) - Notification configuration

**Optional Fields:**
- `artifacts` (array) - Generated files/outputs
- `execution_time_seconds` (number) - Processing time
- `agent` (string) - Agent that processed the WO
- `version` (string) - Schema version

**Status Values:**
- `PENDING` - Work Order received, not started
- `IN_PROGRESS` - Currently being processed
- `DEV_COMPLETED` - Development/execution completed
- `QA_PENDING` - Waiting for QA review
- `QA_APPROVED` - QA passed
- `FAILED` - Processing failed
- `CANCELLED` - Work Order cancelled

---

### **3. Notification Payload Format**

**Purpose:** Standardize the format written to `bridge/inbox/NOTIFY/{wo_id}_notify.json`.

**Current Format (from gateway.py):**

```json
{
  "wo_id": "WO-TEST-NOTIFY-001",
  "telegram": {
    "chat": "boss_private",
    "text": "🧪 Test notification...",
    "meta": {
      "wo_id": "WO-TEST-NOTIFY-001",
      "lane": "dev_oss",
      "status": "COMPLETED"
    }
  },
  "line": null
}
```

**Worker Processing:**
- Read `telegram` object → Extract `chat`, `text`
- Map `chat` to Telegram Chat ID (from `.env.local`)
- Send via Telegram Bot API
- Read `line` object → Extract `room`, `text` (if enabled)
- Send via LINE Messaging API (if configured)

**Chat ID Mapping:**
- `boss_private` → `TELEGRAM_SYSTEM_ALERT_CHAT_ID` (verified - comment confirms "Boss private")
- `ops` → `TELEGRAM_BOT_CHAT_ID_OPS`
- `general` → `TELEGRAM_BOT_CHAT_ID_GENERAL`
- Default fallback → `TELEGRAM_SYSTEM_ALERT_CHAT_ID`

---

### **4. Telegram/Line Channel Mapping Rules** 🔧 **CRITICAL**

**Purpose:** Define exact mapping from notification `chat` names to environment variables.

**Problem:** Worker needs to know how to map `"chat": "boss_private"` → actual Telegram Chat ID from `.env.local`.

**✅ ENVIRONMENT VARIABLE VERIFICATION (COMPLETE - 2025-12-05):**

**Verified by CLC:** All variables checked in `.env.local`

| Variable Name | Status | Actual Value | Notes |
|---------------|--------|--------------|-------|
| `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN` | ✅ **EXISTS** | `"7683891739:AAFnHw3zkXBZecmzIty4iYTv8e_QxZYgAmk"` | Primary token |
| `TELEGRAM_BOT_TOKEN_GPT_ALERTS` | ✅ **EXISTS** | `"7683891739:AAFnHw3zkXBZecmzIty4iYTv8e_QxZYgAmk"` | Fallback (same as SYSTEM_ALERT) |
| `TELEGRAM_GUARD_BOT_TOKEN` | ✅ **EXISTS** | `"7966074921:AAHpvlTMnTBuRNahSD7-23H9JFL_5Ay6r3s"` | Fallback |
| `TELEGRAM_SYSTEM_ALERT_CHAT_ID` | ✅ **EXISTS** | `"6351780525"` | Primary chat ID (Comment: `# Boss private`) |
| `TELEGRAM_BOT_CHAT_ID_GPT_ALERTS` | ✅ **EXISTS** | `"6351780525"` | Fallback (same as SYSTEM_ALERT) |
| `TELEGRAM_GUARD_CHAT_ID` | ✅ **EXISTS** | `"-1002727852946"` | Fallback |
| `TELEGRAM_CHAT_ID_BOSS` | ❌ **MISSING** | N/A | Use `TELEGRAM_SYSTEM_ALERT_CHAT_ID` instead |
| `TELEGRAM_CHAT_ID_OPS` | ❌ **MISSING** | N/A | Use `TELEGRAM_BOT_CHAT_ID_EDGEWORK` or fallback |
| `TELEGRAM_CHAT_ID_GENERAL` | ❌ **MISSING** | N/A | Use `TELEGRAM_SYSTEM_ALERT_CHAT_ID` instead |

**Total TELEGRAM_* variables found:** 14

**See full report:** `g/reports/env_var_verification_report_20251205.md`

**✅ CORRECTED MAPPING TABLE (Based on Actual Variables - Verified 2025-12-05):**

| Chat Name | Primary Env Var | Fallback Chain | Notes |
|-----------|-----------------|----------------|-------|
| `boss_private` | `TELEGRAM_SYSTEM_ALERT_CHAT_ID` | `TELEGRAM_BOT_CHAT_ID_GPT_ALERTS` → `TELEGRAM_GUARD_CHAT_ID` | ✅ **EXISTS** - Comment confirms "Boss private" |
| `ops` | `TELEGRAM_BOT_CHAT_ID_EDGEWORK` | `TELEGRAM_SYSTEM_ALERT_CHAT_ID` → `TELEGRAM_BOT_CHAT_ID_GPT_ALERTS` → `TELEGRAM_GUARD_CHAT_ID` | ✅ **EXISTS** - Uses EDGEWORK group chat |
| `general` | `TELEGRAM_SYSTEM_ALERT_CHAT_ID` | `TELEGRAM_BOT_CHAT_ID_GPT_ALERTS` → `TELEGRAM_GUARD_CHAT_ID` | ✅ **EXISTS** - Same as boss_private |
| `default` | `TELEGRAM_SYSTEM_ALERT_CHAT_ID` | `TELEGRAM_BOT_CHAT_ID_GPT_ALERTS` → `TELEGRAM_GUARD_CHAT_ID` | ✅ **EXISTS** |
| (any other) | `TELEGRAM_SYSTEM_ALERT_CHAT_ID` | `TELEGRAM_BOT_CHAT_ID_GPT_ALERTS` → `TELEGRAM_GUARD_CHAT_ID` | ✅ **EXISTS** - Final fallback |

**Note:** Original spec assumed variables that don't exist (`TELEGRAM_CHAT_ID_BOSS`, etc.). This table uses **actual existing variables** verified in `.env.local`.

**✅ CORRECTED IMPLEMENTATION (Based on Verified Variables):**

```zsh
# Function to resolve chat_id from chat name
# Updated 2025-12-05: Uses actual existing variables from .env.local
resolve_chat_id() {
  local chat_name="$1"
  case "$chat_name" in
    "boss_private")
      # Use SYSTEM_ALERT_CHAT_ID (confirmed "Boss private" in .env.local comment)
      CHAT_ID="${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-${TELEGRAM_BOT_CHAT_ID_GPT_ALERTS:-${TELEGRAM_GUARD_CHAT_ID:-}}}"
      ;;
    "ops")
      # Use EDGEWORK chat (group chat) or fallback to SYSTEM_ALERT
      CHAT_ID="${TELEGRAM_BOT_CHAT_ID_EDGEWORK:-${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-${TELEGRAM_BOT_CHAT_ID_GPT_ALERTS:-${TELEGRAM_GUARD_CHAT_ID:-}}}"
      ;;
    "general")
      # Use SYSTEM_ALERT_CHAT_ID (same as boss_private for now)
      CHAT_ID="${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-${TELEGRAM_BOT_CHAT_ID_GPT_ALERTS:-${TELEGRAM_GUARD_CHAT_ID:-}}}"
      ;;
    *)
      # Default fallback
      CHAT_ID="${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-${TELEGRAM_BOT_CHAT_ID_GPT_ALERTS:-${TELEGRAM_GUARD_CHAT_ID:-}}}"
      ;;
  esac
  
  if [[ -z "$CHAT_ID" ]]; then
    echo "ERROR: No chat_id found for chat: $chat_name" >&2
    return 1
  fi
  echo "$CHAT_ID"
}
```

**Token Resolution (Per Chat/Task - v1.0 Strategy):**

**Important:** Each chat should use its designated bot token (not a single bot for all).

**Verified Token Mapping (Based on Actual .env.local Variables):**

```zsh
# Function to resolve bot token based on chat name
# Each chat uses its designated bot for proper task separation
# Updated 2025-12-05: Uses verified existing tokens from .env.local
resolve_bot_token() {
  local chat_name="$1"
  case "$chat_name" in
    "boss_private")
      # Use SYSTEM_ALERT bot (for boss notifications)
      TOKEN="${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_GPT_ALERTS:-${TELEGRAM_GUARD_BOT_TOKEN:-}}}"
      ;;
    "ops")
      # Use GUARD bot (for ops/group notifications)
      # Note: Using TELEGRAM_GUARD_BOT_TOKEN for ops (per Boss recommendation)
      # Alternative: TELEGRAM_BOT_TOKEN_EDGEWORK exists but using GUARD for consistency
      TOKEN="${TELEGRAM_GUARD_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_EDGEWORK:-${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_GPT_ALERTS:-}}}"
      ;;
    "general")
      # Use SYSTEM_ALERT bot (same as boss_private)
      TOKEN="${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_GPT_ALERTS:-${TELEGRAM_GUARD_BOT_TOKEN:-}}}"
      ;;
    *)
      # Default: Use SYSTEM_ALERT bot
      TOKEN="${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_GPT_ALERTS:-${TELEGRAM_GUARD_BOT_TOKEN:-}}}"
      ;;
  esac
  
  if [[ -z "$TOKEN" ]]; then
    echo "ERROR: No bot token found for chat: $chat_name" >&2
    return 1
  fi
  echo "$TOKEN"
}
```

**Rationale (Based on Verified Variables & Boss Recommendation):**
- `boss_private` → `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN` (verified exists)
- `ops` → `TELEGRAM_GUARD_BOT_TOKEN` (verified exists, using GUARD per Boss recommendation for consistency)
- `general` → `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN` (same as boss_private)
- This allows proper task separation and bot management per channel

**Note:** `TELEGRAM_BOT_TOKEN_EDGEWORK` exists in `.env.local` but using `TELEGRAM_GUARD_BOT_TOKEN` for ops per Boss recommendation. Fallback chain includes EDGEWORK token if GUARD is unavailable.

**LINE Mapping (Future):**

| Room Name | Environment Variable | Fallback |
|-----------|----------------------|----------|
| `default` | `LINE_ROOM_ID_DEFAULT` | `LINE_ROOM_ID` |
| (any other) | `LINE_ROOM_ID` | Final fallback |

**Error Handling:**
- If chat_id cannot be resolved → Log error, skip notification, move file to `bridge/failed/NOTIFY/`
- If token missing → Log error, skip notification, move file to `bridge/failed/NOTIFY/`

---

### **5. State File → Notification Fallback Logic** 🔧 **CRITICAL**

**Purpose:** Define what happens when state file doesn't contain `notify` object or when LAC hasn't written state file yet.

**Problem:** 
- LAC may not write `notify` object in state file
- State file may not exist yet (404 from `/api/wo_status`)
- Worker needs to know where to get notification config

**Fallback Chain (Priority Order):**

#### **Scenario A: Notification file exists in `NOTIFY/`**

**Source:** `bridge/inbox/NOTIFY/{wo_id}_notify.json`

**Processing:**
1. Worker reads notification file directly
2. Extract `telegram` and/or `line` objects
3. Send notifications
4. Move file to `bridge/processed/NOTIFY/`

**Status:** ✅ **PRIMARY PATH** - This is the main flow

---

#### **Scenario B: State file exists but missing `notify` object**

**Source:** `followup/state/{wo_id}.json` (exists, but `notify` field missing or empty)

**Fallback Logic:**
1. Check if state file has `notify` object with `enable: true`
2. If missing or `enable: false` → **Fallback to original WO file**
3. Read `bridge/inbox/LIAM/{wo_id}.json` (original Work Order)
4. Extract `notify` config from WO
5. If WO also missing notify → **Skip notification, log warning**
6. Generate notification payload from WO notify config
7. Send notification
8. Log that fallback was used

**Implementation:**

```zsh
# Function to get notify config with fallback
get_notify_config() {
  local wo_id="$1"
  local state_file="$LUKA_HOME/followup/state/${wo_id}.json"
  local wo_file="$LUKA_HOME/bridge/inbox/LIAM/${wo_id}.json"
  
  # Try state file first
  if [[ -f "$state_file" ]]; then
    local notify_enable=$(jq -r '.notify.enable // false' "$state_file")
    if [[ "$notify_enable" == "true" ]]; then
      local notify_obj=$(jq -r '.notify' "$state_file")
      if [[ "$notify_obj" != "null" && "$notify_obj" != "{}" ]]; then
        echo "$notify_obj"  # Return notify from state
        return 0
      fi
    fi
  fi
  
  # Fallback to original WO file
  if [[ -f "$wo_file" ]]; then
    local notify_obj=$(jq -r '.notify' "$wo_file")
    if [[ "$notify_obj" != "null" && "$notify_obj" != "{}" ]]; then
      echo "$notify_obj"  # Return notify from WO
      log_warning "Used notify config from WO file (state file missing notify)"
      return 0
    fi
  fi
  
  # No notify config found
  log_warning "No notify config found for WO: $wo_id (checked state and WO file)"
  return 1
}
```

---

#### **Scenario C: State file doesn't exist (404)**

**Source:** State file missing, but notification queued via `/api/notify`

**Processing:**
1. Worker reads notification file from `NOTIFY/` (Scenario A applies)
2. No fallback needed - notification file is self-contained

**Status:** ✅ **HANDLED** - Notification file contains all needed data

---

#### **Scenario D: No notification file, no state file, but WO exists**

**Source:** WO processed but no notification queued

**Processing:**
1. Worker does NOT auto-generate notifications
2. Only processes files explicitly queued in `NOTIFY/`
3. If notification needed, must be queued via `/api/notify` or written by agent

**Status:** ✅ **BY DESIGN** - Notifications are explicit, not automatic

---

**Summary Table:**

| State File | Notify in State | WO File | Notify in WO | Action |
|------------|----------------|---------|--------------|--------|
| ✅ Exists | ✅ Present | ✅ Exists | ✅ Present | Use state notify |
| ✅ Exists | ❌ Missing | ✅ Exists | ✅ Present | **Fallback to WO notify** |
| ✅ Exists | ❌ Missing | ✅ Exists | ❌ Missing | Skip, log warning |
| ❌ Missing | N/A | ✅ Exists | ✅ Present | Use WO notify (if notification file exists) |
| ❌ Missing | N/A | ❌ Missing | N/A | Skip, log error |

---

### **6. Worker Retry Rules** 🔧 **CRITICAL**

**Purpose:** Define retry logic for failed API calls (Telegram/Line).

**Problem:** Network issues, rate limits, or temporary API failures should not cause permanent notification loss.

**Retry Configuration:**

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Max Retries** | 3 | Total attempts = initial + 3 retries = 4 attempts |
| **Retry Delay** | 2 seconds | Exponential backoff: 2s, 4s, 8s |
| **Retry Conditions** | HTTP 429, 500, 502, 503, 504 | Rate limit and server errors |
| **No Retry** | HTTP 400, 401, 403 | Client errors (bad request, auth failure) |
| **Timeout** | 10 seconds | Per API call timeout |

**Implementation:**

```zsh
# Function to send Telegram with retry
send_telegram_with_retry() {
  local chat_id="$1"
  local text="$2"
  local token="$3"
  local max_retries=3
  local delay=2
  
  for attempt in $(seq 0 $max_retries); do
    if [[ $attempt -gt 0 ]]; then
      local backoff_delay=$((delay * (2 ** (attempt - 1))))
      echo "Retry attempt $attempt after ${backoff_delay}s delay..." >&2
      sleep "$backoff_delay"
    fi
    
    # Send API request
    local response=$(curl -sS -w "\n%{http_code}" --max-time 10 \
      -X POST "https://api.telegram.org/bot${token}/sendMessage" \
      -d "chat_id=${chat_id}" \
      -d "text=${text}" \
      -d "parse_mode=Markdown" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    # Success
    if [[ "$http_code" == "200" ]]; then
      echo "✅ Telegram sent successfully"
      return 0
    fi
    
    # Client errors (no retry)
    if [[ "$http_code" =~ ^(400|401|403)$ ]]; then
      echo "❌ Client error ($http_code): $body" >&2
      return 1
    fi
    
    # Server errors (retry)
    if [[ "$http_code" =~ ^(429|500|502|503|504)$ ]]; then
      echo "⚠️  Server error ($http_code), will retry..." >&2
      continue
    fi
    
    # Other errors
    echo "❌ Unexpected error ($http_code): $body" >&2
  done
  
  # All retries exhausted
  echo "❌ Failed after $max_retries retries" >&2
  return 1
}
```

**Logging:**

Each retry attempt should be logged:

```json
{
  "timestamp": "2025-12-05T06:45:12Z",
  "wo_id": "WO-TEST-001",
  "channel": "telegram",
  "chat": "boss_private",
  "attempt": 1,
  "http_code": 429,
  "status": "retry",
  "next_retry_in_seconds": 2
}
```

**Final Failure Handling:**

If all retries fail:
1. Log failure to `g/telemetry/notify_worker.jsonl`
2. Move file to `bridge/failed/NOTIFY/{wo_id}_notify.json`
3. Include error details in file (append `_error` field)
4. Continue processing next file (don't crash worker)

**Rate Limit Handling:**

If HTTP 429 (rate limit):
- Use exponential backoff
- Log rate limit hit
- Consider implementing per-chat rate limiting in future

---

### **7. Stale Notification Guard** 🔧 **CRITICAL**

**Purpose:** Prevent processing of stale notifications that may have been queued hours/days ago.

**Problem:** If notification file sits in queue for too long (e.g., worker was down), sending it may be irrelevant or confusing.

**Configuration:**

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Stale Threshold** | 24 hours | Notifications older than 24h are considered stale |
| **Action** | Log + Skip | Don't send, but log for audit |
| **Tag** | `STALE` | Mark in log for easy filtering |

**Implementation:**

```zsh
# Function to check if notification is stale
is_stale_notification() {
  local file_path="$1"
  local stale_hours=24
  
  # Get file modification time
  local file_age_seconds=$(($(date +%s) - $(stat -f %m "$file_path" 2>/dev/null || echo 0)))
  local file_age_hours=$((file_age_seconds / 3600))
  
  if [[ $file_age_hours -gt $stale_hours ]]; then
    return 0  # Is stale
  fi
  return 1  # Not stale
}

# Usage in worker
if is_stale_notification "$notify_file"; then
  log_entry=$(jq -n \
    --arg wo_id "$wo_id" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg result "skipped" \
    --arg reason "stale" \
    --arg channel "telegram" \
    '{timestamp: $timestamp, wo_id: $wo_id, result: $result, reason: $reason, channel: $channel}')
  
  echo "$log_entry" >> "$LOG_FILE"
  mv "$notify_file" "$FAILED_DIR/${wo_id}_notify_stale.json"
  continue  # Skip this file
fi
```

**Log Format for Stale:**

```json
{
  "timestamp": "2025-12-05T06:45:12Z",
  "wo_id": "WO-OLD-001",
  "result": "skipped",
  "reason": "stale",
  "channel": "telegram",
  "file_age_hours": 48
}
```

---

### **8. Worker Metrics Format** 🔧 **CRITICAL**

**Purpose:** Standardize log format for easy dashboard/metrics aggregation.

**Log File:** `g/telemetry/notify_worker.jsonl`

**Required Fields:**

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `timestamp` | string | ISO 8601 UTC timestamp | `"2025-12-05T06:45:12Z"` |
| `wo_id` | string | Work Order ID | `"WO-20251205-EXP-0001"` |
| `result` | string | Processing result | `"success"`, `"failed"`, `"skipped"` |
| `channel` | string | Notification channel | `"telegram"`, `"line"` |
| `chat` | string | Chat/room name | `"boss_private"`, `"ops"` |
| `attempts` | number | Number of retry attempts | `1`, `2`, `3`, `4` |
| `http_code` | number | Final HTTP status code | `200`, `429`, `500` |
| `reason` | string | Reason (if failed/skipped) | `"stale"`, `"missing_chat_id"`, `"rate_limit"` |

**Success Log Example:**

```json
{
  "timestamp": "2025-12-05T06:45:12Z",
  "wo_id": "WO-20251205-EXP-0001",
  "result": "success",
  "channel": "telegram",
  "chat": "boss_private",
  "attempts": 1,
  "http_code": 200
}
```

**Failed Log Example:**

```json
{
  "timestamp": "2025-12-05T06:45:15Z",
  "wo_id": "WO-20251205-EXP-0002",
  "result": "failed",
  "channel": "telegram",
  "chat": "ops",
  "attempts": 4,
  "http_code": 500,
  "reason": "all_retries_exhausted"
}
```

**Skipped Log Example:**

```json
{
  "timestamp": "2025-12-05T06:45:18Z",
  "wo_id": "WO-OLD-001",
  "result": "skipped",
  "channel": "telegram",
  "reason": "stale",
  "file_age_hours": 48
}
```

**Implementation Helper:**

```zsh
# Function to log metrics
log_metric() {
  local wo_id="$1"
  local result="$2"
  local channel="$3"
  local chat="$4"
  local attempts="${5:-1}"
  local http_code="${6:-}"
  local reason="${7:-}"
  
  local log_entry=$(jq -n \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg wo_id "$wo_id" \
    --arg result "$result" \
    --arg channel "$channel" \
    --arg chat "$chat" \
    --argjson attempts "$attempts" \
    --arg http_code "${http_code:-null}" \
    --arg reason "${reason:-null}" \
    '{
      timestamp: $timestamp,
      wo_id: $wo_id,
      result: $result,
      channel: $channel,
      chat: $chat,
      attempts: $attempts,
      http_code: ($http_code | if . == "null" then null else tonumber end),
      reason: ($reason | if . == "null" then null else .)
    }')
  
  echo "$log_entry" >> "$LOG_FILE"
}
```

---

## 📝 **TASK BREAKDOWN**

### **Phase 1: Notification Worker (Priority: HIGH)**

#### **Task 1.1: Create ZSH Notification Worker**

**File:** `apps/opal_gateway/notify_worker.zsh`

**Startup Guard Implementation:**

```zsh
#!/usr/bin/env zsh
# Notification Worker - Startup Guard
set -euo pipefail

# Load .env.local
ENV_FILE="$HOME/02luka/.env.local"
if [[ -f "$ENV_FILE" ]]; then
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
else
  echo "ERROR: .env.local not found at $ENV_FILE" >&2
  exit 1
fi

# Startup Guard: Check critical env vars
if [[ -z "${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-}" ]]; then
  echo "ERROR: TELEGRAM_SYSTEM_ALERT_BOT_TOKEN not set in .env.local" >&2
  echo "Worker cannot start without bot token. Exiting." >&2
  exit 1
fi

if [[ -z "${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-}" ]]; then
  echo "ERROR: TELEGRAM_SYSTEM_ALERT_CHAT_ID not set in .env.local" >&2
  echo "Worker cannot start without chat ID. Exiting." >&2
  exit 1
fi

echo "✅ Startup guard passed - Worker starting..."
# Continue with worker loop...
```

**Requirements:**
- [ ] **Startup Guard** (Critical):
  - [ ] Check `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN` exists
  - [ ] Check `TELEGRAM_SYSTEM_ALERT_CHAT_ID` exists
  - [ ] If missing → log error and exit immediately (prevent worker loop with no config)
  - [ ] Load `.env.local` before checks
- [ ] Poll `bridge/inbox/NOTIFY/` every 5-10 seconds
- [ ] Skip `.tmp` files (atomic write in progress)
- [ ] **Implement Stale Guard** (Section 7):
  - [ ] Check file age (24 hour threshold)
  - [ ] Skip stale files, log with `result: "skipped"`, `reason: "stale"`
  - [ ] Move stale files to `bridge/failed/NOTIFY/` with `_stale` suffix
- [ ] Read JSON payload
- [ ] **Implement Channel Mapping** (Section 4):
  - [ ] `resolve_chat_id()` function with fallback chain
  - [ ] `resolve_bot_token()` function (per chat/task strategy):
    - [ ] `boss_private` → `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`
    - [ ] `ops` → `TELEGRAM_GUARD_BOT_TOKEN` (per Boss recommendation, EDGEWORK available as fallback)
    - [ ] `general` → `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`
  - [ ] Support `boss_private`, `ops`, `general`, `default`
  - [ ] **Use bot token per chat** (not single bot for all)
  - [ ] **NO references to non-existent variables:**
    - [ ] Remove any `TELEGRAM_CHAT_ID_BOSS` references
    - [ ] Remove any `TELEGRAM_CHAT_ID_OPS` references
    - [ ] Remove any `TELEGRAM_CHAT_ID_GENERAL` references
    - [ ] Remove any `TELEGRAM_BOT_CHAT_ID_BOSS_PRIVATE` references
    - [ ] Remove any `TELEGRAM_BOT_TOKEN_EDGEWORK` references (use `TELEGRAM_GUARD_BOT_TOKEN` for ops)
- [ ] **Implement Retry Logic** (Section 6):
  - [ ] Max 3 retries with exponential backoff (2s, 4s, 8s)
  - [ ] Retry on HTTP 429, 500, 502, 503, 504
  - [ ] No retry on HTTP 400, 401, 403
  - [ ] 10-second timeout per API call
  - [ ] Log each retry attempt
- [ ] **Implement Fallback Logic** (Section 5):
  - [ ] If notification file missing notify → check state file
  - [ ] If state file missing notify → check original WO file
  - [ ] Log fallback usage
  - [ ] Skip notification if no config found (log warning)
- [ ] Send Telegram via direct API call (with retry)
- [ ] **Telegram only in v1.0** (LINE deferred to future phase)
- [ ] Move processed file to `bridge/processed/NOTIFY/`
- [ ] Move failed file to `bridge/failed/NOTIFY/` (after retries exhausted)
- [ ] **Log metrics** (Section 8) to `g/telemetry/notify_worker.jsonl`:
  - [ ] Use standardized format with all required fields
  - [ ] Include `result`, `channel`, `chat`, `attempts`, `http_code`, `reason`
- [ ] Handle errors gracefully (skip malformed files, continue on failure)

**Estimated Time:** 3-4 hours (increased due to retry/fallback logic)

**Dependencies:**
- `g/tools/system_alert_send.zsh` (exists ✅)
- `.env.local` with Telegram tokens (exists ✅)

#### **Task 1.2: Create LaunchAgent for Worker**

**File:** `~/Library/LaunchAgents/com.02luka.notify.worker.plist`

**Requirements:**
- [ ] Run `notify_worker.zsh` on boot
- [ ] KeepAlive: true
- [ ] ThrottleInterval: 30 (prevent feedback loops)
- [ ] Logs to `~/02luka/logs/notify_worker.stdout.log`
- [ ] Restart on crash

**Estimated Time:** 30 minutes

#### **Task 1.3: Test Notification Worker**

**Test Script:** `apps/opal_gateway/test_notify_worker.zsh`

**Test Cases:**
- [ ] Create test notification file in `NOTIFY/`
- [ ] Verify worker picks it up within 10 seconds
- [ ] Verify Telegram message sent successfully
- [ ] Verify file moved to `processed/`
- [ ] Verify log entry created
- [ ] **Test Channel Mapping:**
  - [ ] Test `boss_private` → resolves correct chat_id
  - [ ] Test `ops` → resolves correct chat_id
  - [ ] Test `default` → uses fallback chat_id
  - [ ] Test unknown chat → uses default fallback
- [ ] **Test Retry Logic:**
  - [ ] Simulate HTTP 429 → verify retry with backoff
  - [ ] Simulate HTTP 500 → verify retry
  - [ ] Simulate HTTP 400 → verify no retry (fails immediately)
  - [ ] Verify all retries exhausted → file moved to `failed/`
- [ ] **Test Fallback Logic:**
  - [ ] Notification file with notify → uses notification file
  - [ ] Notification file missing notify, state file has notify → uses state file
  - [ ] Both missing notify, WO file has notify → uses WO file (fallback)
  - [ ] All missing notify → skips, logs warning
- [ ] Test error handling (malformed JSON, missing token, missing chat_id)

**Estimated Time:** 1 hour

---

### **Phase 2: State File Specification (Priority: MEDIUM)**

#### **Task 2.1: Create State File Spec Document**

**File:** `apps/opal_gateway/STATE_FILE_SPEC.md`

**Content:**
- [ ] Complete JSON schema with examples
- [ ] Status value enumeration
- [ ] Field descriptions
- [ ] Integration guide for LAC/Hybrid Agent
- [ ] Migration notes (if updating existing format)

**Estimated Time:** 1 hour

#### **Task 2.2: Create State File Validator**

**File:** `apps/opal_gateway/validate_state_file.py` (optional)

**Purpose:** Validate state files before LAC writes them.

**Requirements:**
- [ ] JSON schema validation
- [ ] Required field checks
- [ ] Type validation
- [ ] Status value validation

**Estimated Time:** 1 hour (optional)

---

### **Phase 3: LAC/Hybrid Agent Integration (Priority: HIGH)**

#### **Task 3.1: Update LAC to Write State Files**

**Files:** LAC agent scripts (TBD based on actual LAC implementation)

**Requirements:**
- [ ] After processing WO, write `followup/state/{wo_id}.json`
- [ ] Follow STATE_FILE_SPEC.md format
- [ ] **Include `notify` config from WO** (preserve from original WO file)
- [ ] If WO missing notify → set `notify.enable: false` (don't generate default)
- [ ] Update `last_update` timestamp
- [ ] Set appropriate `status` value
- [ ] **Critical:** Ensure `notify` object structure matches spec (for fallback logic)

**Estimated Time:** 4-6 hours (depends on LAC complexity)

**Dependencies:**
- Task 2.1 (State File Spec) ✅

#### **Task 3.2: Update Hybrid Agent/ATG**

**Similar to Task 3.1, but for other agents.**

**Estimated Time:** 2-4 hours per agent

---

### **Phase 4: End-to-End Testing (Priority: HIGH)**

#### **Task 4.1: Create E2E Test Script**

**File:** `apps/opal_gateway/test_e2e_notification.sh`

**Test Flow:**
1. [ ] Submit WO via `POST /api/wo` (curl)
2. [ ] Verify file created in `bridge/inbox/LIAM/`
3. [ ] Manually trigger LAC/Agent (or simulate state file write)
4. [ ] Verify state file created in `followup/state/`
5. [ ] Query status via `POST /api/wo_status` (should return 200, not 404)
6. [ ] Queue notification via `POST /api/notify`
7. [ ] Verify notification file in `bridge/inbox/NOTIFY/`
8. [ ] Wait for worker to process (max 10 seconds)
9. [ ] Verify Telegram message received
10. [ ] Verify file moved to `processed/`

**Estimated Time:** 2 hours

#### **Task 4.2: Integration Test with Opal**

**Requirements:**
- [ ] Configure Cloudflare Tunnel (if not done)
- [ ] Test actual Opal app → Gateway flow
- [ ] Verify end-to-end notification delivery
- [ ] Document any issues/fixes

**Estimated Time:** 2-3 hours

---

## 🧪 **TESTING STRATEGY**

### **Unit Tests**

**Notification Worker:**
- Test JSON parsing
- Test Telegram API call (mock)
- Test file moving logic
- Test error handling

**State File Validator:**
- Test schema validation
- Test required fields
- Test status values

### **Integration Tests**

**Worker + Gateway:**
- Gateway writes notification file
- Worker picks it up and sends
- Verify end-to-end flow

**State File + Status API:**
- Agent writes state file
- Gateway reads via `/api/wo_status`
- Verify correct data returned

### **E2E Tests**

**Complete Flow:**
- Opal → Gateway → Agent → State → Notification → Worker → Telegram
- Verify all steps succeed
- Verify error handling at each step

---

## 📊 **SUCCESS METRICS**

### **Phase 1 Success:**
- ✅ Worker running and processing files
- ✅ At least 1 test notification sent successfully
- ✅ Worker logs show successful processing
- ✅ No crashes or infinite loops

### **Phase 2 Success:**
- ✅ State file spec documented
- ✅ Example state files created
- ✅ Validator passes (if implemented)

### **Phase 3 Success:**
- ✅ LAC writes state files after processing WO
- ✅ State files follow spec format
- ✅ `/api/wo_status` returns 200 (not 404) for processed WOs

### **Phase 4 Success:**
- ✅ E2E test script passes all steps
- ✅ Real Opal app can submit WO and receive notification
- ✅ Status queries return actual state

---

## 🚨 **RISKS & MITIGATION**

### **Risk 1: Worker Polling Overhead**
**Impact:** High CPU usage if polling too frequently  
**Mitigation:** Use 5-10 second intervals, consider file watcher instead of polling

### **Risk 2: Telegram API Rate Limits**
**Impact:** Notifications delayed or failed  
**Mitigation:** Implement rate limiting, queue management, retry logic

### **Risk 3: State File Format Mismatch**
**Impact:** `/api/wo_status` returns errors or wrong data  
**Mitigation:** Create validator, document spec clearly, test with examples

### **Risk 4: Missing LINE Integration**
**Impact:** Only Telegram works, Line notifications fail  
**Mitigation:** Document LINE API requirements, implement basic LINE support or mark as future work

### **Risk 5: LAC Integration Complexity**
**Impact:** Takes longer than estimated  
**Mitigation:** Start with simple state file write, iterate based on LAC architecture

---

## 📅 **ESTIMATED TIMELINE**

### **Quick Start (Minimum Viable):**
- **Day 1:** Notification Worker (ZSH) + LaunchAgent + Basic Test
- **Day 2:** State File Spec + LAC Integration (basic)
- **Day 3:** E2E Testing + Fixes

**Total:** 3 days for basic working system

### **Complete Implementation:**
- **Week 1:** Phase 1 + Phase 2 (Worker + Spec)
- **Week 2:** Phase 3 (LAC/Agent Integration)
- **Week 3:** Phase 4 (E2E Testing + Production Deployment)

**Total:** 3 weeks for production-ready system

---

## 🔗 **DEPENDENCIES**

### **External:**
- ✅ Telegram Bot API (available)
- ✅ LINE Messaging API (if needed)
- ✅ Cloudflare Tunnel (needs verification)
- ✅ Opal App (needs configuration)

### **Internal:**
- ✅ `system_alert_send.zsh` (exists)
- ✅ `.env.local` with tokens (exists)
- ✅ Gateway v1.1 (exists)
- ❌ LAC/Hybrid Agent integration (needs implementation)
- ❌ State file writers (needs implementation)

---

## 📚 **REFERENCE DOCUMENTATION**

### **Existing Docs:**
- `apps/opal_gateway/gateway.py` - Gateway implementation
- `apps/opal_gateway/OPAL_CONFIG.md` - Opal configuration guide
- `g/tools/system_alert_send.zsh` - Telegram sender
- `apps/opal_gateway/test_gateway.py` - Gateway test suite

### **To Be Created:**
- `apps/opal_gateway/notify_worker.zsh` - Notification worker
- `apps/opal_gateway/STATE_FILE_SPEC.md` - State file specification
- `apps/opal_gateway/test_notify_worker.zsh` - Worker tests
- `apps/opal_gateway/test_e2e_notification.sh` - E2E tests

---

## ✅ **NEXT STEPS**

### **Immediate (This Week):**
1. **✅ Spec Updated** - Added 3 critical sections:
   - ✅ Channel Mapping Rules (Section 4)
   - ✅ State File Fallback Logic (Section 5)
   - ✅ Worker Retry Rules (Section 6)
2. **Approve this spec** - Confirm approach and priorities
3. **Implement Notification Worker (ZSH)** - Task 1.1 (now includes all 3 critical features)
4. **Create LaunchAgent** - Task 1.2
5. **Test Worker** - Task 1.3 (now includes channel mapping, retry, and fallback tests)

### **Short Term (Next Week):**
5. **Create State File Spec** - Task 2.1
6. **Integrate with LAC** - Task 3.1
7. **E2E Testing** - Task 4.1

### **Medium Term (Following Weeks):**
8. **Production Deployment** - Cloudflare Tunnel, monitoring
9. **Documentation** - User guides, troubleshooting
10. **Optimization** - Performance tuning, error handling improvements

---

## 🎯 **DECISION POINTS**

### **Decision 1: Worker Implementation**
- **Option A:** ZSH (quick, reuse existing tools) ✅ **RECOMMENDED**
- **Option B:** Python (more robust, testable)

**Recommendation:** Start with ZSH, migrate to Python if needed.

### **Decision 2: Polling vs File Watcher**
- **Option A:** Polling (simpler, works everywhere) ✅ **RECOMMENDED**
- **Option B:** File watcher (more efficient, platform-specific)

**Recommendation:** Start with polling (5-10s interval), optimize later.

### **Decision 3: LINE Integration**
- **Option A:** Implement now (complete system)
- **Option B:** Telegram only, LINE later ✅ **RECOMMENDED**

**Recommendation:** Start with Telegram, add LINE if needed.

---

## 📝 **APPROVAL CHECKLIST**

Before starting implementation:
- [x] **Spec updated with all critical sections** ✅
  - [x] Channel Mapping Rules (Section 4) + Env Var Checklist
  - [x] State File Fallback Logic (Section 5)
  - [x] Worker Retry Rules (Section 6)
  - [x] Stale Notification Guard (Section 7)
  - [x] Worker Metrics Format (Section 8)
- [x] **Gateway code polished** ✅
  - [x] Unified error format (`error_response()` helper)
  - [x] `/stats` returns HTTP 500 on error
- [x] **V1.0 Scope clarified** ✅
  - [x] Telegram only (LINE deferred)
- [ ] **Env Var Verification** ⚠️ **REQUIRED BEFORE IMPLEMENTATION**
  - [ ] Check `.env.local` for actual variable names
  - [ ] Update mapping table if needed
  - [ ] Document which variables exist vs need to be added
- [ ] Boss approves this spec
- [ ] Priorities confirmed (Phase 1 first)
- [ ] Worker implementation choice (ZSH vs Python) - **ZSH recommended**
- [ ] Timeline acceptable (3 days quick start vs 3 weeks complete)
- [ ] Dependencies verified (tokens, tools, etc.)

---

**End of Feature Development Plan**

**Status:** Ready for Approval  
**Next Action:** Boss review and approval → Begin Phase 1
