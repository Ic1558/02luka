# Alerts & Ops Status Setup Guide

**Last Updated:** 2025-10-16
**Agent:** Reportbot
**Status:** ✅ PRODUCTION READY

---

## 📋 Overview

The 02LUKA alerting system provides:

- **Reportbot Agent** - Monitors system health, generates alerts for WARN/FAIL conditions
- **OPS Status Badge** - Real-time ops summary at `/api/reports/summary`
- **Native HTTP Transport** - Zero dependencies (no node-fetch)
- **Tolerant Badge Inspection** - Badge issues don't block PRs

---

## 🚀 Quick Start

### 1. Run Reportbot

```bash
# Run with default output (g/reports/OPS_SUMMARY.json)
node agents/reportbot/index.cjs

# Run with custom output path
node agents/reportbot/index.cjs /tmp/ops_summary.json
```

### 2. Check OPS Summary API

```bash
curl http://127.0.0.1:4000/api/reports/summary
```

**Response Examples:**

✅ **Success** (file exists, valid JSON):
```json
{
  "status": "ok",
  "level": "info",
  "timestamp": "2025-10-16T12:00:00.000Z",
  "alerts": {
    "total": 5,
    "critical": 0,
    "fail": 0,
    "warn": 1,
    "info": 4
  },
  "recent": [
    {
      "level": "WARN",
      "message": "Service UI returned 503",
      "timestamp": "2025-10-16T11:59:00.000Z"
    }
  ]
}
```

⚠️ **Tolerant** (missing file):
```json
{
  "status": "unknown",
  "note": "summary_not_generated",
  "hint": "Run: node agents/reportbot/index.cjs /tmp/ops_summary.json"
}
```

⚠️ **Tolerant** (unreadable file):
```json
{
  "status": "unknown",
  "note": "summary_unreadable",
  "hint": "Check file permissions on g/reports/OPS_SUMMARY.json"
}
```

⚠️ **Tolerant** (invalid JSON):
```json
{
  "status": "unknown",
  "note": "summary_invalid_json",
  "hint": "OPS_SUMMARY.json contains invalid JSON"
}
```

**Key Feature:** All responses return HTTP 200, so badge issues don't block PRs.

---

## 🔧 Configuration

### Environment Variables

```bash
# Optional: Webhook for FAIL/CRITICAL alerts
export ALERT_WEBHOOK_URL="https://hooks.slack.com/services/REMOVED_FOR_SECURITY
```

### Alert Levels

| Level | Description | Webhook Sent |
|-------|-------------|--------------|
| INFO | Informational message | No |
| WARN | Warning condition | No |
| FAIL | Service failure | Yes |
| CRITICAL | System-wide failure | Yes |

---

## 📊 OPS Summary Structure

**File:** `g/reports/OPS_SUMMARY.json`

**Schema:**
```json
{
  "status": "ok|warn|fail",
  "level": "info|warn|error",
  "timestamp": "ISO 8601 timestamp",
  "alerts": {
    "total": 10,
    "critical": 0,
    "fail": 1,
    "warn": 2,
    "info": 7
  },
  "recent": [
    {
      "level": "FAIL",
      "message": "Service API is unreachable",
      "timestamp": "2025-10-16T12:00:00.000Z"
    }
  ]
}
```

**Status Determination:**
- `ok` - No FAIL or WARN in recent alerts
- `warn` - At least one WARN in recent alerts
- `fail` - At least one FAIL or CRITICAL in recent alerts

---

## 🔍 System Checks

Reportbot automatically monitors:

### 1. Service Health

Checks HTTP status of:
- **API** - `http://127.0.0.1:4000/api/capabilities`
- **UI** - `http://127.0.0.1:5173`
- **MCP FS** - `http://127.0.0.1:8765/health`

**Alerts:**
- WARN if service returns non-2xx status
- FAIL if service is unreachable

### 2. Smoke Tests

Runs `./run/smoke_api_ui.sh` and parses output:
- WARN for `⚠️  WARN` lines
- FAIL for `❌ FAIL` lines
- INFO if all tests pass

---

## 🛠️ Troubleshooting

### Badge Shows "unknown"

**Symptom:** `/api/reports/summary` returns `status: "unknown"`

**Diagnosis:**
1. Check if OPS_SUMMARY.json exists:
   ```bash
   ls -la g/reports/OPS_SUMMARY.json
   ```

2. Try reading the file:
   ```bash
   cat g/reports/OPS_SUMMARY.json
   ```

3. Validate JSON:
   ```bash
   jq . g/reports/OPS_SUMMARY.json
   ```

**Fix:**
```bash
# Regenerate summary
node agents/reportbot/index.cjs

# Check API response
curl http://127.0.0.1:4000/api/reports/summary | jq .
```

### Webhook Not Sending

**Symptom:** FAIL/CRITICAL alerts not reaching webhook

**Diagnosis:**
1. Check webhook URL configured:
   ```bash
   echo $ALERT_WEBHOOK_URL
   ```

2. Test manually:
   ```bash
   curl -X POST "$ALERT_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -d '{"text":"Test alert from 02LUKA"}'
   ```

3. Check reportbot logs for errors

**Fix:**
```bash
# Set webhook URL
export ALERT_WEBHOOK_URL="https://your-webhook-url"

# Run reportbot with webhook
node agents/reportbot/index.cjs
```

### Service Health Checks Failing

**Symptom:** All services reported as FAIL

**Diagnosis:**
1. Check if services are running:
   ```bash
   lsof -i :4000  # API server
   lsof -i :5173  # UI server
   lsof -i :8765  # MCP FS server
   ```

2. Test service URLs directly:
   ```bash
   curl http://127.0.0.1:4000/api/capabilities
   curl http://127.0.0.1:5173
   curl http://127.0.0.1:8765/health
   ```

**Fix:**
```bash
# Start missing services
cd boss-api && node server.cjs &
cd boss-ui && npm run dev &
# (MCP FS server start command)
```

---

## 🔄 Integration with CI/CD

### GitHub Actions

**Option 1: Run in workflow** (manual)

```yaml
jobs:
  ops-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Reportbot
        run: node agents/reportbot/index.cjs
      - name: Check OPS Summary
        run: |
          cat g/reports/OPS_SUMMARY.json
          # Fail if status is "fail"
          if [ "$(jq -r .status g/reports/OPS_SUMMARY.json)" = "fail" ]; then
            echo "❌ OPS status is FAIL"
            exit 1
          fi
```

**Option 2: Scheduled** (cron)

```yaml
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours

jobs:
  ops-monitoring:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: node agents/reportbot/index.cjs
      - run: curl -X POST ${{ secrets.ALERT_WEBHOOK_URL }} \
          -d @g/reports/OPS_SUMMARY.json
```

---

## 🚢 PR Creation Helper

The `scripts/pr_push_reportbot.sh` helper automates PR creation for reportbot changes.

### Usage

```bash
# Use default branch (feat/alerts-reportbot)
bash scripts/pr_push_reportbot.sh

# Use custom branch name
bash scripts/pr_push_reportbot.sh my-custom-branch
```

### What It Does

1. **Checks out branch** (creates if doesn't exist)
2. **Stages files:**
   - `.github/workflows/ci.yml`
   - `agents/reportbot/index.cjs`
   - `boss-api/server.cjs`
   - `g/manuals/alerts_setup.md`
   - `scripts/pr_push_reportbot.sh`
3. **Creates commit** with standard message
4. **Pushes to GitHub**
5. **Prints PR URL** for quick access

### Fallback Behavior

If push fails (missing GitHub credentials):
1. Creates timestamped patch in `g/patches/`
2. Prints instructions for manual apply:
   ```bash
   git am < g/patches/reportbot_tolerance_YYYYMMDD_HHMMSS.patch
   git push origin feat/alerts-reportbot
   ```

---

## 📈 Architecture

### Reportbot Agent

**File:** `agents/reportbot/index.cjs`

**Components:**
- `AlertNotifier` - Manages alert history, saves alerts, sends webhooks
- `SystemMonitor` - Checks service health, runs smoke tests
- `generateOpsSummary()` - Creates OPS_SUMMARY.json

**Dependencies:** Zero (uses native Node.js modules only)
- `fs` - File operations
- `path` - Path handling
- `https` - Webhook requests
- `child_process` - Smoke test execution

### Badge Tolerance

**File:** `boss-api/server.cjs`

**Endpoint:** `GET /api/reports/summary`

**Tolerance Features:**
1. Missing file → Returns `status: "unknown"`
2. Unreadable file → Returns `status: "unknown"`
3. Invalid JSON → Returns `status: "unknown"`
4. Unexpected errors → Returns `status: "unknown"`

**Always returns HTTP 200** - Badge issues don't block PRs.

---

## 🧪 Testing

### Unit Tests

```bash
# Test reportbot with custom output
node agents/reportbot/index.cjs /tmp/ops_summary.json

# Verify output
cat /tmp/ops_summary.json
jq . /tmp/ops_summary.json
```

### Integration Tests

```bash
# Run reportbot
node agents/reportbot/index.cjs

# Test API endpoint
curl http://127.0.0.1:4000/api/reports/summary | jq .

# Test tolerance (remove file)
rm g/reports/OPS_SUMMARY.json
curl http://127.0.0.1:4000/api/reports/summary | jq .
# Should return: {"status":"unknown","note":"summary_not_generated",...}

# Test tolerance (invalid JSON)
echo "not json" > g/reports/OPS_SUMMARY.json
curl http://127.0.0.1:4000/api/reports/summary | jq .
# Should return: {"status":"unknown","note":"summary_invalid_json",...}
```

### Smoke Test

```bash
# Run smoke test and check reportbot catches issues
./run/smoke_api_ui.sh
node agents/reportbot/index.cjs
jq .alerts g/reports/OPS_SUMMARY.json
```

---

## 📝 Changelog

### 2025-10-16 - Badge Tolerance & Native HTTP

**Added:**
- Tolerant badge inspection (missing/unreadable/invalid JSON → HTTP 200)
- Native HTTP transport (replaced node-fetch)
- OPS_SUMMARY.json generation
- scripts/pr_push_reportbot.sh helper
- This manual (g/manuals/alerts_setup.md)

**Changed:**
- `/api/reports/summary` always returns 200 (never 500)
- Reportbot uses native https module (zero dependencies)

**Fixed:**
- Badge issues no longer block PRs
- Service health checks work without node-fetch

---

## 🔗 Related Documentation

- [Discord Integration](../docs/integrations/discord.md)
- [API Endpoints](../docs/api_endpoints.md)
- [Smoke Test Guide](../run/smoke_api_ui.sh)

---

## 💡 Tips & Best Practices

1. **Run reportbot regularly** - Schedule via cron or GitHub Actions
2. **Monitor OPS_SUMMARY.json** - Add to gitignore if generated frequently
3. **Test badge tolerance** - Verify unknown status doesn't break UI
4. **Configure webhooks** - Get instant alerts for FAIL/CRITICAL
5. **Check alert history** - Review `boss/alerts/` for past issues

---

## ❓ FAQ

**Q: Why does badge always show "unknown"?**
A: Check if reportbot has run recently. Run: `node agents/reportbot/index.cjs`

**Q: Can I customize alert levels?**
A: Yes, edit `ALERT_LEVELS` in `agents/reportbot/index.cjs`

**Q: How often should reportbot run?**
A: Recommended: every 5-15 minutes for real-time monitoring

**Q: What if webhook URL is invalid?**
A: Reportbot logs error but continues (graceful degradation)

**Q: Can I add custom health checks?**
A: Yes, add services to `checkServiceHealth()` in SystemMonitor class

---

**Need Help?** Check `agents/reportbot/index.cjs` inline comments or run with `--help`
