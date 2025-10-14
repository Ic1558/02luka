---
project: system-maintenance
tags: [ops,retention,alerts,ci]
---

# Retention & CI Alerts System

**Version:** 1.0
**Date:** 2025-10-09

## Overview

Automated cleanup and alerting system for 02luka repository health.

## ✅ Retention & Hygiene

### What it does
- Cleans `.trash/` files older than 30 days
- Removes `g/reports/proof/*_proof.md` older than 30 days
- Runs daily at 09:05 ICT via GitHub Actions
- Can be run manually anytime

### Usage

**Manual cleanup:**
```bash
make tidy-retention
```

**Output:**
```
🧹 Cleaning old files (>30 days)...
  .trash/: 0 files removed
  g/reports/proof/: 3 proof files removed
✅ Total removed: 3 files
```

### Scheduled automation
- **Workflow:** `.github/workflows/retention.yml`
- **Schedule:** Daily at 09:05 ICT (02:05 UTC)
- **Manual trigger:** `gh workflow run "Retention (proof + trash)"`

### Configuration
- **Retention period:** 30 days (configurable in Makefile)
- **Directories cleaned:**
  - `.trash/` - all files
  - `g/reports/proof/` - only `*_proof.md` files

## ✅ CI Alerts (Already Active)

### What it does
- Monitors Daily Proof workflow failures
- Sends alerts to Slack and/or Teams
- Triggered automatically when daily-proof fails

### Workflows
1. **Daily Proof:** `.github/workflows/daily-proof.yml`
   - Runs daily at 08:12 ICT
   - Validates SOT structure
   - Generates proof report

2. **Alerting:** `.github/workflows/daily-proof-alerting.yml`
   - Triggers when Daily Proof fails
   - Sends notifications to configured channels

### Setup Slack alerts

**1. Create Slack webhook:**
- Go to Slack → Apps → Incoming Webhooks
- Create webhook for #alerts channel
- Copy webhook URL (e.g., `https://hooks.slack.com/services/...`)

**2. Add GitHub secret:**
```bash
# Via GitHub UI:
# Settings → Secrets and variables → Actions → New repository secret
# Name: SLACK_WEBHOOK_URL
# Value: <your webhook URL>

# Or via gh CLI:
gh secret set SLACK_WEBHOOK_URL
# Paste webhook URL when prompted
```

**3. Verify:**
```bash
gh secret list
# Should show: SLACK_WEBHOOK_URL
```

### Setup Teams alerts (optional)

**1. Create Teams webhook:**
- Teams → Channel → Connectors → Incoming Webhook
- Copy webhook URL

**2. Add GitHub secret:**
```bash
gh secret set TEAMS_WEBHOOK_URL
# Paste webhook URL when prompted
```

### Alert message format

**Slack/Teams notification:**
```
🚨 Daily Proof Workflow Failed!

Repository: Ic1558/02luka
Branch: main
Commit: abc1234
Workflow: [View logs]

Please check the workflow logs and fix any issues.
```

## Testing

**Test retention locally:**
```bash
make tidy-retention
```

**Trigger Daily Proof manually:**
```bash
gh workflow run "Daily Proof (Option C)"
```

**View workflow status:**
```bash
gh run list --workflow="Daily Proof (Option C)" --limit 3
gh run list --workflow="Retention (proof + trash)" --limit 3
```

**Check secrets:**
```bash
gh secret list
```

## Monitoring

**Check latest proof:**
```bash
make status
```

**View retention workflow runs:**
```bash
gh run list --workflow=retention.yml --limit 5
```

**View alert workflow runs:**
```bash
gh run list --workflow=daily-proof-alerting.yml --limit 5
```

## Troubleshooting

**Retention not running:**
- Check workflow permissions: Settings → Actions → Workflow permissions
- Should be "Read and write permissions"

**Alerts not sending:**
- Verify secrets are set: `gh secret list`
- Check workflow logs: `gh run view <run-id>`
- Verify webhook URLs are correct

**Manual cleanup:**
```bash
# Clean specific directory
find .trash -type f -mtime +30 -delete

# Check what would be cleaned (dry run)
find .trash -type f -mtime +30 -print
find g/reports/proof -name "*_proof.md" -mtime +30 -print
```

## Maintenance

**Update retention period:**
Edit `Makefile`, change `-mtime +30` to desired days:
```makefile
find .trash -type f -mtime +60 -delete  # 60 days instead of 30
```

**Update schedule:**
Edit `.github/workflows/retention.yml`, change cron:
```yaml
schedule:
  - cron: "5 2 * * 0"  # Weekly on Sunday instead of daily
```

**Disable alerting:**
Remove or comment out secrets:
```bash
gh secret remove SLACK_WEBHOOK_URL
gh secret remove TEAMS_WEBHOOK_URL
```

## Files

**Makefile targets:**
- `make tidy-retention` - Run cleanup
- `make status` - Check system status

**Workflows:**
- `.github/workflows/retention.yml` - Scheduled cleanup
- `.github/workflows/daily-proof.yml` - Daily validation
- `.github/workflows/daily-proof-alerting.yml` - Failure alerts

**Documentation:**
- This file: `g/manuals/RETENTION_AND_ALERTS.md`
