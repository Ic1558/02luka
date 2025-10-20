# Discord OPS Integration — Phase 5

Comprehensive documentation for 02LUKA's Discord notification system integrated into the ops atomic flow.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Components](#components)
- [Configuration](#configuration)
- [Integration Points](#integration-points)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

### System Design

The Discord integration follows a **multi-layer architecture** with graceful degradation:

```
┌─────────────────────────────────────────────────────────────┐
│                    ops_atomic.sh (Main Orchestrator)         │
│                                                               │
│  Phase 1: Smoke Tests          → PASS/WARN/FAIL counters     │
│  Phase 2: API Verification     → PASS/WARN/FAIL counters     │
│  Phase 3: Notify Prep          → PASS/WARN/FAIL counters     │
│  Phase 4: Report Generation    → PASS/WARN/FAIL counters     │
│                                                               │
│  ┌──────────────── Phase 5: Discord Notifications ────────┐  │
│  │                                                         │  │
│  │  1. Determine Overall Status (pass/warn/fail)          │  │
│  │  2. Format Phase Details (• Phase N — STATUS)          │  │
│  │  3. Extract Report Link (from OPS_SUMMARY.json)        │  │
│  │  4. Call discord_ops_notify.sh                         │  │
│  │     └─→ Returns: PASS|WARN|SKIP                        │  │
│  │  5. Parse Result & Update Counters                     │  │
│  │  6. Refresh Report (include Phase 5 in final report)   │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────┐
│              scripts/discord_ops_notify.sh                   │
│                                                               │
│  • Validates webhook configuration                           │
│  • Formats message with emoji & status                       │
│  • Builds JSON payload (via Python)                          │
│  • POSTs to localhost:4000/api/discord/notify                │
│  • Retries on 5xx errors (2 attempts, 2s delay)              │
│  • Returns: PASS (200), WARN (error), SKIP (503)             │
└───────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────┐
│              boss-api/server.cjs (Express API)               │
│                    POST /api/discord/notify                  │
│                                                               │
│  • Validates payload (content required)                      │
│  • Normalizes level (info/warn/error)                        │
│  • Resolves webhook URL:                                     │
│     1. DISCORD_WEBHOOK_MAP[channel]                          │
│     2. DISCORD_WEBHOOK_MAP.default                           │
│     3. DISCORD_WEBHOOK_DEFAULT                               │
│  • Calls webhook_relay.cjs                                   │
│  • Returns: 200 (ok), 503 (not configured), 502 (failed)    │
└───────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────┐
│         agents/discord/webhook_relay.cjs                     │
│                                                               │
│  • Native Node.js HTTPS (zero dependencies)                  │
│  • Timeout: 10 seconds                                       │
│  • Validates payload structure                               │
│  • POSTs to Discord webhook URL                              │
│  • Returns: Promise<{ok: true}> or throws Error              │
└───────────────────────────────────────────────────────────────┘
                               ↓
                        Discord API
                    (External Service)
```

### Data Flow

```
Phase Results → OPS_ATOMIC_*.md (report file)
              → reportbot (aggregator)
              → OPS_SUMMARY.json (summary)
              → discord_ops_notify.sh (dispatcher)
              → /api/discord/notify (API endpoint)
              → webhook_relay.cjs (HTTPS client)
              → Discord API (HTTPS POST)
              → Discord Channel (message appears)
```

### Resilience Design

**Key Principle: Phase 5 never blocks Phases 1-4**

- ✅ Missing webhook → SKIP (not FAIL)
- ✅ Network timeout → WARN (not FAIL)
- ✅ Discord API error → WARN (not FAIL)
- ✅ Retry logic → 2 attempts with 2-second delay
- ✅ Report always generated regardless of Discord status

## Components

### 1. ops_atomic.sh — Phase 5 Integration

**Location:** `run/ops_atomic.sh` (lines 236-294)

**Purpose:** Orchestrates Discord notification after Phases 1-4 complete

**Key Functions:**

```bash
# Entry point (line 236)
overall_status_before_notify="$(determine_overall_status)"
counts_text="PASS=$PASS WARN=$WARN FAIL=$FAIL"

# Format phase details (lines 241-246)
for ((i = 0; i < ${#PHASE_NAMES[@]}; i++)); do
  phase_detail_lines+="• ${PHASE_NAMES[$i]} — ${PHASE_STATUS[$i]}\n"
done

# Extract report link (lines 248-251)
if link=$(SUMMARY_PATH="$REPO_ROOT/g/reports/OPS_SUMMARY.json" extract_report_link); then
  report_link="$link"
fi

# Call Discord notifier (lines 254-260)
discord_output=$("$REPO_ROOT/scripts/discord_ops_notify.sh" \
  --status "$overall_status_before_notify" \
  --summary "$counts_text" \
  --details "$phase_detail_lines" \
  --link "$report_link" \
  --title "OPS Atomic $(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>&1)

# Parse result (lines 267-270)
discord_result=$(echo "$discord_output" | awk -F= '/DISCORD_RESULT=/{print $2}' | tail -n1)
```

**Exit Codes:**
- Phase 5 PASS → Increments PASS counter
- Phase 5 WARN → Increments WARN counter
- Phase 5 never causes FAIL

### 2. scripts/discord_ops_notify.sh — Notification Dispatcher

**Location:** `scripts/discord_ops_notify.sh`

**Purpose:** Formats and sends Discord notifications via API

**Command-Line Interface:**

```bash
scripts/discord_ops_notify.sh \
  --status <pass|warn|fail|unknown> \
  --summary "PASS=3 WARN=0 FAIL=0" \
  --details "• Phase 1 — PASS\n• Phase 2 — WARN" \
  --link <https://report-url> \
  --channel <channel-name> \
  --title "Custom Title"
```

**Status Normalization:**

| Input             | Output   | Emoji |
|-------------------|----------|-------|
| pass, ok, success | pass     | ✅    |
| warn, warning     | warn     | ⚠️    |
| fail, failed      | fail     | ❌    |
| (other)           | unknown  | ℹ️    |

**Message Format:**

```
<emoji> <title> — <STATUS>
<summary>
<details>
Latest report: <link>
```

**Environment Variables:**

| Variable                    | Default                                   | Description                |
|-----------------------------|-------------------------------------------|----------------------------|
| `DISCORD_WEBHOOK_DEFAULT`   | (none)                                    | Primary webhook URL        |
| `DISCORD_WEBHOOK_MAP`       | (none)                                    | JSON map of channels       |
| `REPORT_CHANNEL`            | `reports`                                 | Default channel name       |
| `DISCORD_NOTIFY_API_URL`    | `http://127.0.0.1:4000/api/discord/notify` | API endpoint               |
| `DISCORD_NOTIFY_TIMEOUT`    | `8`                                       | Request timeout (seconds)  |
| `DISCORD_NOTIFY_RETRY_DELAY`| `2`                                       | Retry delay (seconds)      |

**Return Codes:**

```bash
DISCORD_RESULT=PASS   # HTTP 200, message sent successfully
DISCORD_RESULT=WARN   # HTTP 4xx/5xx, failed to send
DISCORD_RESULT=SKIP   # HTTP 503, webhook not configured
```

### 3. agents/reportbot/index.cjs — Summary Aggregator

**Location:** `agents/reportbot/index.cjs`

**Purpose:** Aggregates ops summary from API + filesystem

**Command-Line Interface:**

```bash
node agents/reportbot/index.cjs [options]

Options:
  --write             Persist summary to g/reports/OPS_SUMMARY.json
  --text              Output human-readable text instead of JSON
  --no-api            Skip API fetch (filesystem only)
  --counts a,b,c      Override pass,warn,fail counts (e.g. 3,1,0)
  --status value      Override overall status (pass|warn|fail)
  --latest path       Provide path to latest report
  --channel name      Override target channel (default: reports)
```

**Data Sources:**

1. **Filesystem:** `g/reports/latest` marker → `OPS_ATOMIC_*.md` files
2. **API:** `http://127.0.0.1:4000/api/reports/summary`
3. **Overrides:** Command-line flags take precedence

**Output Formats:**

**JSON Mode (default):**
```json
{
  "generatedAt": "2025-10-18T04:30:00.000Z",
  "status": "pass",
  "pass": 5,
  "warn": 0,
  "fail": 0,
  "channel": "reports",
  "source": "api",
  "summary": "PASS=5 WARN=0 FAIL=0",
  "report": {
    "file": "OPS_ATOMIC_251018_043000.md",
    "path": "/full/path/to/report.md",
    "link": "https://example.com/reports/..."
  }
}
```

**Text Mode (--text):**
```
PASS — PASS=5 WARN=0 FAIL=0 | Latest: OPS_ATOMIC_251018_043000.md
```

**Status Logic:**

```javascript
function determineStatus(counts) {
  if (counts.fail > 0) return 'fail';
  if (counts.warn > 0) return 'warn';
  if (counts.pass > 0) return 'pass';
  return 'unknown';
}
```

### 4. boss-api/server.cjs — API Endpoint

**Location:** `boss-api/server.cjs` (lines 263-293)

**Endpoint:** `POST /api/discord/notify`

**Request:**

```json
{
  "content": "Message text (required)",
  "level": "info|warn|error (optional, default: info)",
  "channel": "channel-name (optional, default: default)"
}
```

**Response:**

| Status | Body                                       | Meaning                      |
|--------|--------------------------------------------|------------------------------|
| 200    | `{"ok": true}`                             | Message sent successfully    |
| 400    | `{"error": "content is required"}`         | Invalid request              |
| 502    | `{"error": "Failed to send..."}`           | Discord webhook failed       |
| 503    | `{"error": "webhook not configured"}`      | No webhook URL set           |

**Webhook Resolution Logic:**

```javascript
function resolveDiscordWebhook(channelName) {
  const normalized = channelName.trim() || 'default';

  // 1. Check DISCORD_WEBHOOK_MAP[channel]
  if (discordWebhookMap[normalized]) {
    return discordWebhookMap[normalized];
  }

  // 2. Fallback to DISCORD_WEBHOOK_MAP.default
  if (normalized !== 'default' && discordWebhookMap.default) {
    return discordWebhookMap.default;
  }

  // 3. Fallback to DISCORD_WEBHOOK_DEFAULT
  return DISCORD_WEBHOOK_DEFAULT;
}
```

**Level → Emoji Mapping:**

```javascript
const levelEmojis = {
  info: 'ℹ️',
  warn: '⚠️',
  error: '🚨'
};
```

**Security:**

- ✅ Rate limiting: 100 req/min per IP
- ✅ Mention safety: `allowed_mentions: { parse: [] }` (prevents @everyone)
- ✅ Content-length validation
- ✅ Request timeout: 10 seconds

### 5. agents/discord/webhook_relay.cjs — Webhook Client

**Location:** `agents/discord/webhook_relay.cjs`

**Purpose:** Zero-dependency HTTPS client for Discord webhooks

**API:**

```javascript
const { postDiscordWebhook } = require('./webhook_relay.cjs');

await postDiscordWebhook('https://discord.com/api/webhooks/...', {
  content: 'Message text',
  // ... other Discord webhook fields
});
```

**Features:**

- ✅ Native Node.js HTTPS (no external dependencies)
- ✅ 10-second timeout
- ✅ Promise-based (async/await compatible)
- ✅ Validates payload structure
- ✅ Returns status code in error objects
- ✅ User-Agent: `02luka-webhook-relay/1.0`

**Error Handling:**

```javascript
try {
  await postDiscordWebhook(url, payload);
} catch (error) {
  console.error(`Discord webhook failed:`, error.message);
  // error.statusCode available if Discord returned non-2xx
}
```

## Configuration

### Step 1: Obtain Discord Webhook URL

1. Go to Discord Server Settings → Integrations → Webhooks
2. Click "New Webhook" (or copy existing webhook URL)
3. Copy the webhook URL format: `https://discord.com/api/webhooks/{id}/{token}`

### Step 2: Configure Environment

Choose **Option A** (simple, single channel) or **Option B** (advanced, multiple channels):

#### Option A: Single Channel (Recommended for Most Users)

Add to `boss-api/.env`:

```bash
# Discord Configuration (Single Channel)
DISCORD_WEBHOOK_DEFAULT=https://discord.com/api/webhooks/your-id/your-token
REPORT_CHANNEL=ops
```

#### Option B: Multiple Channels (Advanced)

Add to `boss-api/.env`:

```bash
# Discord Configuration (Multiple Channels)
DISCORD_WEBHOOK_MAP={"alerts":"https://discord.com/api/webhooks/...","ops":"https://discord.com/api/webhooks/...","reports":"https://discord.com/api/webhooks/..."}
REPORT_CHANNEL=ops
```

**Channel Resolution:**
- Request for channel "ops" → Uses `DISCORD_WEBHOOK_MAP.ops`
- Request for channel "unknown" → Falls back to `DISCORD_WEBHOOK_MAP.default`
- No channel specified → Uses `DISCORD_WEBHOOK_DEFAULT`

### Step 3: Restart API Server

```bash
# Stop current server
pkill -f "node.*server.cjs"

# Start server
cd boss-api && node server.cjs &

# Verify server is running
curl http://127.0.0.1:4000/healthz
```

### Step 4: Verify Configuration

```bash
# Test Discord endpoint
bash run/discord_notify_example.sh

# Expected output:
# ✅ Success (200)
```

## Integration Points

### Triggering Discord Notifications

#### Method 1: Via ops_atomic.sh (Automatic)

```bash
bash run/ops_atomic.sh
```

Phase 5 automatically triggers after Phases 1-4 complete.

#### Method 2: Via discord_ops_notify.sh (Manual)

```bash
scripts/discord_ops_notify.sh \
  --status "pass" \
  --summary "PASS=5 WARN=0 FAIL=0" \
  --details "• All systems operational" \
  --title "Manual Notification"
```

#### Method 3: Via API (Programmatic)

```bash
curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Deployment complete ✅\nAll tests passed",
    "level": "info",
    "channel": "ops"
  }'
```

#### Method 4: Via reportbot + Custom Script

```bash
# Get latest summary
summary=$(node agents/reportbot/index.cjs --text)

# Send to Discord
scripts/discord_ops_notify.sh \
  --status "pass" \
  --summary "$summary" \
  --title "Daily Report"
```

### Scheduling

Add to LaunchAgent (macOS) or cron (Linux):

**Example: Daily ops run at 3 AM**

```xml
<!-- ~/Library/LaunchAgents/com.02luka.ops.daily.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.02luka.ops.daily</string>
  <key>Program</key>
  <string>/bin/bash</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>cd /path/to/02luka-repo && bash run/ops_atomic.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>3</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/Users/you/Library/Logs/02luka/ops_daily.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/you/Library/Logs/02luka/ops_daily.err</string>
</dict>
</plist>
```

Load with:
```bash
launchctl load ~/Library/LaunchAgents/com.02luka.ops.daily.plist
```

## API Reference

### POST /api/discord/notify

Send a Discord notification

**Request:**

```json
{
  "content": "string (required, max 1800 chars recommended)",
  "level": "info|warn|error (optional, default: info)",
  "channel": "string (optional, default: default)"
}
```

**Response (200 Success):**

```json
{
  "ok": true
}
```

**Response (400 Bad Request):**

```json
{
  "error": "content is required"
}
```

**Response (502 Bad Gateway):**

```json
{
  "error": "Failed to send Discord notification"
}
```

**Response (503 Service Unavailable):**

```json
{
  "error": "Discord webhook is not configured"
}
```

**Rate Limits:**
- API: 100 req/min per IP (enforced by boss-api)
- Discord: 5 req/2sec per webhook (enforced by Discord)

**Examples:**

```bash
# Info notification
curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{"content":"System startup complete","level":"info"}'

# Warning notification
curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{"content":"High memory usage (85%)","level":"warn"}'

# Error notification to specific channel
curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{"content":"Database connection failed","level":"error","channel":"alerts"}'
```

## Testing

### Quick Smoke Test

```bash
# Test 1: Reportbot (no Discord)
node agents/reportbot/index.cjs --text --no-api
# Expected: "STATUS — PASS=X WARN=Y FAIL=Z | Latest: ..."

# Test 2: API health
curl http://127.0.0.1:4000/healthz
# Expected: {"status":"ok",...}

# Test 3: Discord examples (requires webhook)
bash run/discord_notify_example.sh
# Expected: ✅ Success (200) for each example
```

### Full Integration Test

```bash
# Run complete ops atomic flow
bash run/ops_atomic.sh

# Expected output:
# === Phase 1: Smoke Tests ===
# ...
# === Phase 5: Discord Notifications ===
# Discord notification delivered (HTTP 200).
# DISCORD_RESULT=PASS
# ...
# Overall status: PASS
# Totals: PASS=5 WARN=0 FAIL=0
```

### Validation Script

```bash
# Run full validation (includes Discord if configured)
bash run/validate_full.sh

# Check validation report
cat g/reports/VALIDATION_*.md
```

## Troubleshooting

### Issue: "Discord webhook not configured"

**Symptom:**
```
Discord webhook not configured; skipping notification.
DISCORD_RESULT=SKIP
```

**Cause:** `DISCORD_WEBHOOK_DEFAULT` and `DISCORD_WEBHOOK_MAP` are both unset

**Solution:**
```bash
# Add to boss-api/.env
echo 'DISCORD_WEBHOOK_DEFAULT=https://discord.com/api/webhooks/...' >> boss-api/.env

# Restart API server
pkill -f "node.*server.cjs" && cd boss-api && node server.cjs &
```

---

### Issue: "Failed to send Discord notification" (502)

**Symptom:**
```
Failed to deliver Discord notification (HTTP 502).
DISCORD_RESULT=WARN
```

**Possible Causes:**
1. Invalid webhook URL
2. Discord API rate limit exceeded
3. Network timeout
4. Webhook deleted on Discord side

**Debug Steps:**

```bash
# 1. Verify webhook URL format
echo $DISCORD_WEBHOOK_DEFAULT
# Should be: https://discord.com/api/webhooks/{id}/{token}

# 2. Test webhook directly
curl -X POST "$DISCORD_WEBHOOK_DEFAULT" \
  -H "Content-Type: application/json" \
  -d '{"content":"Test"}'
# Expected: Empty response with HTTP 204

# 3. Check API server logs
tail -f ~/Library/Logs/02luka/boss-api.log

# 4. Test with verbose output
bash -x scripts/discord_ops_notify.sh --status "pass" --summary "test"
```

---

### Issue: Discord message not appearing

**Symptom:** HTTP 200 returned but message doesn't appear in Discord

**Possible Causes:**
1. Wrong webhook URL (different channel)
2. Webhook pointed to channel you don't have access to
3. Content filtered by Discord (very rare)

**Solution:**
```bash
# 1. Verify webhook channel
# Go to Discord → Server Settings → Integrations → Webhooks
# Confirm the webhook points to the correct channel

# 2. Test with simple message
curl -X POST "$DISCORD_WEBHOOK_DEFAULT" \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello World"}'

# 3. Check Discord channel permissions
```

---

### Issue: "Request timeout"

**Symptom:**
```
Discord notification encountered issues (HTTP 000).
DISCORD_RESULT=WARN
```

**Cause:** Network timeout (8 seconds by default)

**Solution:**
```bash
# Increase timeout
export DISCORD_NOTIFY_TIMEOUT=15
bash run/ops_atomic.sh

# Or edit scripts/discord_ops_notify.sh line 16:
# TIMEOUT_SECONDS=${DISCORD_NOTIFY_TIMEOUT:-15}
```

---

### Issue: Phase 5 marked as WARN

**Symptom:** Phase 5 shows WARN in final report

**Explanation:** This is **expected behavior** when:
- Webhook not configured (SKIP)
- Network error
- Discord API error

**Important:** Phase 5 WARN does **not** fail the overall ops run. This is intentional.

**To investigate:**
```bash
# Check Phase 5 output in report
cat g/reports/OPS_ATOMIC_*.md | grep -A 10 "Phase 5"

# Check Discord notification status
grep "DISCORD_RESULT" g/reports/OPS_ATOMIC_*.md
```

---

### Issue: "allowed_mentions" errors

**Symptom:** Discord API returns 400 with mention-related error

**Explanation:** This should **never** happen because we set `allowed_mentions: { parse: [] }`

**If it does happen:**
```bash
# Check boss-api/server.cjs line 135
# Should have:
{
  content: finalContent,
  allowed_mentions: { parse: [] }
}
```

---

### Debug Mode

Enable verbose logging:

```bash
# Set debug flags
export DEBUG=1
export DISCORD_NOTIFY_TIMEOUT=30

# Run with bash -x for full trace
bash -x run/ops_atomic.sh 2>&1 | tee ops_debug.log

# Check /tmp files
cat /tmp/discord_notify_error.log
cat /tmp/cmd.out
cat /tmp/cmd.err
```

## See Also

- **Verification Report:** `g/reports/DISCORD_PHASE5_VERIFICATION_251018.txt`
- **Quick Checklist:** `docs/PHASE5_CHECKLIST.md`
- **Example Script:** `run/discord_notify_example.sh`
- **API Server:** `boss-api/server.cjs`
- **Ops Atomic:** `run/ops_atomic.sh`

---

**Last Updated:** 2025-10-18
**Maintained by:** CLC (Chief Learning Coordinator)
**Status:** Production Ready ✅
