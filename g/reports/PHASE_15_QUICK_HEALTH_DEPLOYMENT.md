# Phase15 Quick Health - Deployment Guide

**Date:** 2025-11-10 (ICT)  
**Status:** ✅ Deployed and Verified

## Overview

Phase15 Quick Health system provides automated health monitoring for MCP Bridge and MLS services, with integration for both local macOS (LaunchAgent) and CI (GitHub Actions).

## Components

### 1. Core Script
- **File:** `tools/phase15_quick_health.zsh`
- **Features:**
  - Exit code tracking (0 = OK, 1 = FAILED)
  - JSON output mode (`--json`)
  - Plist validation (Label, ProgramArguments, permissions, owner)
  - ICT timestamp
  - Quick actions (`--restart-bridge`, `--tail-log`, `--fix-ledger-today`)
  - Auto-skip launchctl checks on non-macOS systems (CI mode)

### 2. CI Integration
- **File:** `.github/workflows/phase15-quick-health.yml`
- **Schedule:** Daily at 08:15 ICT (`cron: '15 1 * * *'`)
- **Features:**
  - Maintenance mode guard
  - JSON artifact upload
  - Fail job if health check fails
  - Runs on `workflow_dispatch` or `schedule`

### 3. LaunchAgent (macOS)
- **File:** `LaunchAgents/com.02luka.phase15.quickhealth.plist`
- **Schedule:** Every 10 minutes (`StartInterval: 600`)
- **Output:** `~/02luka/mls/status/phase15_quickhealth.json`
- **Logs:** `~/Library/Logs/phase15_quickhealth.{log,err}`

### 4. MLS Integration
- **File:** `tools/phase15_quick_health_to_mls.zsh`
- **Purpose:** Log health check results to MLS ledger
- **Type:** `health`
- **Context:** `bridge` (if OK) or `ci` (if failed)

### 5. Notification
- **File:** `tools/phase15_quick_health_notify.zsh`
- **Purpose:** Send notification if health check fails
- **Integration:** Telegram (if `telegram_notify.zsh` exists)

### 6. Make Targets
- `make quick-health` - Run health check (human-readable)
- `make quick-health-json` - Run health check (JSON output)

## Usage

### Local (macOS)
```bash
# Human-readable mode
make quick-health

# JSON output
make quick-health-json

# Or directly
~/02luka/tools/phase15_quick_health.zsh
~/02luka/tools/phase15_quick_health.zsh --json
```

### CI (GitHub Actions)
```bash
# Manual trigger
gh workflow run phase15-quick-health.yml

# Or wait for scheduled run (08:15 ICT daily)
```

### LaunchAgent Setup
```bash
# Install LaunchAgent
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.02luka.phase15.quickhealth.plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.02luka.phase15.quickhealth.plist
launchctl kickstart -k gui/$(id -u)/com.02luka.phase15.quickhealth

# Check status
launchctl list | grep com.02luka.phase15.quickhealth

# View latest result
cat ~/02luka/mls/status/phase15_quickhealth.json | jq .
```

### MLS Integration
```bash
# Log health check to MLS
~/02luka/tools/phase15_quick_health_to_mls.zsh
```

### Notification
```bash
# Check and notify if failed
~/02luka/tools/phase15_quick_health_notify.zsh
```

## Quick Actions

```bash
# Restart MCP Bridge
~/02luka/tools/phase15_quick_health.zsh --restart-bridge

# View live logs
~/02luka/tools/phase15_quick_health.zsh --tail-log

# Fix today's ledger
~/02luka/tools/phase15_quick_health.zsh --fix-ledger-today
```

## Health Check Output

### Human-Readable Mode
- Service status (PID, LastExitStatus)
- Plist validation (syntax, Label, ProgramArguments, permissions, owner)
- MLS streak and ledger status
- Quick actions

### JSON Mode
```json
{
  "ts_ict": "2025-11-10T22:18:40+0700",
  "mcp_bridge": {
    "label": "com.02luka.gg.mcp-bridge",
    "pid": 78139,
    "last_exit_status": null,
    "program": "/bin/zsh",
    "script_path": "/Users/icmini/02luka/tools/gg_mcp_bridge.zsh",
    "keep_alive": true,
    "run_at_load": true,
    "ok": true
  },
  "mls": {
    "streak_file_exists": false,
    "streak": 0,
    "ledger_today_path": "/Users/icmini/02luka/mls/ledger/2025-11-10.jsonl",
    "ledger_exists": true,
    "ledger_jsonl_ok": true,
    "entries_today": 1,
    "ok": true
  },
  "ok": true
}
```

## Exit Codes

- `0` - All checks passed
- `1` - One or more checks failed

## Maintenance Mode

Set `MAINTENANCE_MODE=1` to skip health checks:
- CI: Uses `vars.MAINTENANCE_MODE`
- LaunchAgent: Can be added to plist `EnvironmentVariables`

## Files Created

1. `.github/workflows/phase15-quick-health.yml` - CI workflow
2. `LaunchAgents/com.02luka.phase15.quickhealth.plist` - LaunchAgent config
3. `tools/phase15_quick_health_to_mls.zsh` - MLS integration
4. `tools/phase15_quick_health_notify.zsh` - Notification script
5. `Makefile` - Added `quick-health` and `quick-health-json` targets

## Verification

```bash
# Test script
make quick-health

# Test JSON output
make quick-health-json | jq -e '.ok == true'

# Test plist
plutil -lint LaunchAgents/com.02luka.phase15.quickhealth.plist

# Test LaunchAgent (after installation)
launchctl list | grep com.02luka.phase15.quickhealth
```

## Next Steps

1. Install LaunchAgent on macOS machines
2. Monitor CI runs for health check results
3. Set up notifications (if needed)
4. Review health check results in `~/02luka/mls/status/phase15_quickhealth.json`

---

**Deployment Status:** ✅ Complete  
**Last Updated:** 2025-11-10T22:20:00+0700
