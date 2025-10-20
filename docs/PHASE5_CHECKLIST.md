# Phase 5 Discord Integration — Quick Checklist

One-page reference for setting up and verifying Discord notifications in 02LUKA ops flow.

## 📋 Pre-Flight Checks

- [ ] API server running (`curl http://127.0.0.1:4000/healthz` → 200)
- [ ] Reports directory exists (`ls g/reports/`)
- [ ] Node.js available (`node --version` → v18+)
- [ ] Bash scripts executable (`ls -l run/*.sh` → `-rwxr-xr-x`)

## 🔧 Setup (One-Time)

### Step 1: Get Discord Webhook

- [ ] Go to Discord Server Settings → Integrations → Webhooks
- [ ] Click "New Webhook" (or copy existing)
- [ ] Copy webhook URL: `https://discord.com/api/webhooks/{id}/{token}`

### Step 2: Configure Environment

Choose **Simple** (most users) or **Advanced** (multi-channel):

**Simple (Single Channel):**
```bash
echo 'DISCORD_WEBHOOK_DEFAULT=https://discord.com/api/webhooks/...' >> boss-api/.env
```

**Advanced (Multiple Channels):**
```bash
echo 'DISCORD_WEBHOOK_MAP={"alerts":"https://...","ops":"https://..."}' >> boss-api/.env
```

### Step 3: Restart API Server

```bash
pkill -f "node.*server.cjs"
cd boss-api && node server.cjs &
```

### Step 4: Verify

- [ ] Run: `bash run/discord_notify_example.sh`
- [ ] Expected: `✅ Success (200)` for all examples
- [ ] Check Discord channel for test messages

## ✅ Daily Operations

### Run Full Ops Flow

```bash
bash run/ops_atomic.sh
```

**Expected Output:**
```
=== Phase 1: Smoke Tests ===
...
=== Phase 5: Discord Notifications ===
Discord notification delivered (HTTP 200).
DISCORD_RESULT=PASS
...
Overall status: PASS
```

### Manual Discord Notification

```bash
scripts/discord_ops_notify.sh \
  --status "pass" \
  --summary "PASS=5 WARN=0 FAIL=0" \
  --title "Manual Test"
```

### Get Latest Summary

```bash
node agents/reportbot/index.cjs --text
```

**Output:** `PASS — PASS=5 WARN=0 FAIL=0 | Latest: OPS_ATOMIC_*.md`

## 🔍 Troubleshooting

### Problem: "Discord webhook not configured"

**Fix:**
```bash
# Verify webhook is set
grep DISCORD_WEBHOOK boss-api/.env

# If empty, add webhook URL
echo 'DISCORD_WEBHOOK_DEFAULT=https://...' >> boss-api/.env

# Restart server
pkill -f "node.*server.cjs" && cd boss-api && node server.cjs &
```

### Problem: "Failed to send Discord notification" (502)

**Check:**
- [ ] Webhook URL is correct (starts with `https://discord.com/api/webhooks/`)
- [ ] Webhook not deleted on Discord side
- [ ] No rate limit (max 5 req/2sec per webhook)

**Test webhook directly:**
```bash
curl -X POST "$DISCORD_WEBHOOK_DEFAULT" \
  -H "Content-Type: application/json" \
  -d '{"content":"Test"}' \
  -w "\nHTTP: %{http_code}\n"
```

**Expected:** HTTP: 204 (no content, success)

### Problem: Phase 5 shows WARN

**This is normal when:**
- Webhook not configured → Returns `SKIP`
- Network error → Returns `WARN`
- Discord API error → Returns `WARN`

**Important:** Phase 5 WARN does NOT fail the overall ops run.

**To investigate:**
```bash
# Check Phase 5 output in latest report
cat g/reports/latest | xargs cat | grep -A 10 "Phase 5"

# Check DISCORD_RESULT
grep "DISCORD_RESULT" g/reports/OPS_ATOMIC_*.md | tail -1
```

### Problem: Message doesn't appear in Discord

**Check:**
- [ ] Correct Discord channel (verify webhook points to expected channel)
- [ ] You have access to that channel
- [ ] Message not filtered (very rare)

**Test:**
```bash
curl -X POST "$DISCORD_WEBHOOK_DEFAULT" \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello from 02LUKA ✅"}'
```

## 📊 Quick Reference

### Files & Locations

| Component                     | Path                                | Purpose                       |
|-------------------------------|-------------------------------------|-------------------------------|
| Phase 5 Integration           | `run/ops_atomic.sh` (lines 236-294) | Orchestrator                  |
| Notification Dispatcher       | `scripts/discord_ops_notify.sh`     | CLI tool                      |
| Summary Aggregator            | `agents/reportbot/index.cjs`        | Data collector                |
| API Endpoint                  | `boss-api/server.cjs` (lines 263-293) | HTTP API                      |
| Webhook Client                | `agents/discord/webhook_relay.cjs`  | HTTPS client                  |
| Configuration                 | `boss-api/.env`                     | Environment vars              |
| Examples                      | `run/discord_notify_example.sh`     | Usage demos                   |
| Reports                       | `g/reports/OPS_ATOMIC_*.md`         | Generated reports             |
| Summary JSON                  | `g/reports/OPS_SUMMARY.json`        | Latest summary                |

### Environment Variables

| Variable                    | Required? | Default                          | Description                |
|-----------------------------|-----------|----------------------------------|----------------------------|
| `DISCORD_WEBHOOK_DEFAULT`   | ⚠️ Yes*   | (none)                           | Primary webhook URL        |
| `DISCORD_WEBHOOK_MAP`       | No        | (none)                           | Multi-channel JSON map     |
| `REPORT_CHANNEL`            | No        | `reports`                        | Default channel name       |
| `DISCORD_NOTIFY_API_URL`    | No        | `http://127.0.0.1:4000/api/...`  | API endpoint               |
| `DISCORD_NOTIFY_TIMEOUT`    | No        | `8`                              | Timeout (seconds)          |

*Either `DISCORD_WEBHOOK_DEFAULT` or `DISCORD_WEBHOOK_MAP` must be set

### Discord Result Codes

| Code   | HTTP | Meaning                          | Action                        |
|--------|------|----------------------------------|-------------------------------|
| `PASS` | 200  | Message sent successfully        | ✅ None                       |
| `WARN` | 4xx/5xx | Failed to send (error/timeout) | ⚠️ Check webhook/network      |
| `SKIP` | 503  | Webhook not configured           | ⚠️ Add webhook URL to .env    |

### Status Logic

```
FAIL if fail > 0
WARN if warn > 0
PASS if pass > 0
UNKNOWN otherwise
```

### Emoji Mapping

| Level   | Emoji | Usage                           |
|---------|-------|---------------------------------|
| info    | ℹ️    | General notifications           |
| warn    | ⚠️    | Warnings, degraded service      |
| error   | 🚨    | Errors, failures                |
| pass    | ✅    | Success                         |
| fail    | ❌    | Critical failure                |

## 🚀 Quick Commands

### Test Everything

```bash
# 1. Health check
curl -s http://127.0.0.1:4000/healthz | jq

# 2. Test reportbot
node agents/reportbot/index.cjs --text --no-api

# 3. Test Discord (if configured)
bash run/discord_notify_example.sh

# 4. Full ops run
bash run/ops_atomic.sh

# 5. Validate system
bash run/validate_full.sh
```

### View Reports

```bash
# Latest report
cat g/reports/latest | xargs cat

# All reports (newest first)
ls -t g/reports/OPS_ATOMIC_*.md | head -5

# Latest summary
cat g/reports/OPS_SUMMARY.json | jq
```

### Send Custom Notification

```bash
# Via script
scripts/discord_ops_notify.sh \
  --status "info" \
  --summary "Custom message" \
  --title "Manual Alert"

# Via API
curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello from API","level":"info"}'
```

## 📚 Documentation

- **Full Documentation:** `docs/DISCORD_OPS_INTEGRATION.md`
- **Verification Report:** `g/reports/DISCORD_PHASE5_VERIFICATION_251018.txt`
- **Example Script:** `run/discord_notify_example.sh`

## 🎯 Success Criteria

**Phase 5 is working correctly when:**

- [ ] `bash run/ops_atomic.sh` completes all 5 phases
- [ ] Phase 5 returns `DISCORD_RESULT=PASS`
- [ ] Discord message appears in channel
- [ ] Message contains:
  - [ ] Status emoji (✅/⚠️/❌)
  - [ ] Phase summaries
  - [ ] PASS/WARN/FAIL counts
  - [ ] Report link (if configured)
- [ ] Report generated in `g/reports/`
- [ ] `OPS_SUMMARY.json` updated

**Phase 5 is configured but skipped when:**

- [ ] `DISCORD_RESULT=SKIP` appears
- [ ] Message: "Discord webhook not configured"
- [ ] This is **expected** if webhook not set
- [ ] Does **not** fail the overall ops run

## ⚡ Pro Tips

1. **Use Multiple Channels:** Separate alerts, ops, and reports
   ```bash
   DISCORD_WEBHOOK_MAP='{"alerts":"https://...","ops":"https://...","reports":"https://..."}'
   ```

2. **Schedule Daily Runs:** Use LaunchAgent/cron for automatic notifications

3. **Monitor Logs:** Check `~/Library/Logs/02luka/` for debugging

4. **Rate Limits:** Discord allows 5 req/2sec per webhook

5. **Message Length:** Keep under 1800 chars (auto-truncated at 1800)

6. **Test First:** Always run `bash run/discord_notify_example.sh` before production

7. **Graceful Degradation:** Phase 5 never blocks Phases 1-4

8. **Retry Logic:** 2 automatic attempts with 2-second delay

---

**Last Updated:** 2025-10-18
**Version:** 1.0
**Status:** Production Ready ✅

**Quick Help:**
```bash
# Show this file
cat docs/PHASE5_CHECKLIST.md

# Full docs
cat docs/DISCORD_OPS_INTEGRATION.md

# Verification report
cat g/reports/DISCORD_PHASE5_VERIFICATION_251018.txt
```
