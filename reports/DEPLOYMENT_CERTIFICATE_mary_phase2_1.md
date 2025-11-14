# Deployment Certificate: Mary Phase 2.1 (Alerts + Metrics)

**Deployment Date:** 2025-11-12T04:10:00Z
**System:** Mary Phase 2.1 - Telegram Alerts + Daily Metrics
**Status:** ✅ DEPLOYED

## Verification Results

### LaunchAgents
```
com.02luka.mary.metrics.daily - Daily metrics (00:05)
com.02luka.mary.alerts - Error alerts (every 60s)
com.02luka.mary.dispatcher - WO dispatcher (every 15s)
com.02luka.cls.cmdin - CLS watcher (event-driven)
```

### Test Results
- Metrics collection: ✅ Daily metrics file created
- Health check: ✅ Updated with quarantine/queue checks
- Alerts: ✅ Watcher running (needs Telegram config for testing)

## Artifacts

- **Backup**: `g/reports/deployments/mary_phase2_1_YYYYMMDD_HHMMSS`
- **Rollback**: `tools/rollback_mary_phase2_1.zsh`
- **Scripts**:
  - `tools/mary_alerts_watch.zsh` - Error alert watcher
  - `tools/mary_metrics_collect_daily.zsh` - Daily metrics collector
  - `tools/mary_dispatcher_health_check.zsh` - Updated health check

## Features Deployed

### 1. Telegram Alerts
- **Trigger**: CLS .do errors >3 in 10 minutes
- **Rate Limit**: 1 alert per 15 minutes
- **Content**: Top 3 error samples + quick-fix hints
- **Config**: Uses `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` (env or `config/telegram.env`)

### 2. Daily Metrics
- **Schedule**: 00:05 daily
- **Metrics**:
  - Mary: processed, quarantined, pending
  - CLS: processed, errors
  - Performance: avg process time, p95 latency
- **Output**: `g/reports/mary_metrics_YYYYMM/mary_metrics_YYYYMMDD.json`
- **README**: Monthly summary in `README.md`

### 3. Health Check Updates
- **Fail Conditions**:
  - Quarantine count > 0
  - Entry queue > 50
- **Metrics Check**: Validates metrics file structure
- **Exit Code**: Non-zero if unhealthy

## Configuration

### Telegram Setup
Create `config/telegram.env`:
```bash
TELEGRAM_BOT_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"
```

Or set environment variables:
```bash
export TELEGRAM_BOT_TOKEN="your_bot_token"
export TELEGRAM_CHAT_ID="your_chat_id"
```

## Usage

### Test Alerts
```bash
# Create 4 error files quickly
for i in {1..4}; do
  echo "error test $i" > bridge/inbox/CLS_CMD/error-test-$i.do
done
# Wait 10 minutes, check Telegram
```

### View Metrics
```bash
# Today's metrics
cat g/reports/mary_metrics_$(date +%Y%m)/mary_metrics_$(date +%Y%m%d).json | jq

# Monthly summary
cat g/reports/mary_metrics_$(date +%Y%m)/README.md
```

### Health Check
```bash
tools/mary_dispatcher_health_check.zsh
```

## Logs

- Alerts: `logs/mary_alerts.log`
- Metrics: `logs/mary_metrics.log`
- LaunchAgent stdout: `logs/mary_alerts.out.log`, `logs/mary_metrics.out.log`
- LaunchAgent stderr: `logs/mary_alerts.err.log`, `logs/mary_metrics.err.log`

## Rollback

If needed, run:
```bash
tools/rollback_mary_phase2_1.zsh
```

## Signed Off

✅ Deployment verified and operational
✅ Alerts watcher active (needs Telegram config)
✅ Daily metrics collector scheduled
✅ Health check updated with fail conditions
