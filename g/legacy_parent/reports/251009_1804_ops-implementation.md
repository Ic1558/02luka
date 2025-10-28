---
project: system-stabilization
tags: [ops,implementation,complete]
---

# Ops Menu Implementation: Retention + CI Alerts

**Date:** 2025-10-09 18:04
**Status:** ✅ COMPLETE
**Commit:** b30b674

## Completed Features

### ✅ 2) CI Alerts (Already Active)

**Status:** Already implemented, documented

**Existing workflows:**
- `.github/workflows/daily-proof.yml` - Daily validation (08:12 ICT)
- `.github/workflows/daily-proof-alerting.yml` - Failure notifications

**Alert channels:**
- Slack (requires `SLACK_WEBHOOK_URL` secret)
- Teams (requires `TEAMS_WEBHOOK_URL` secret)

**Next step for user:**
```bash
# Add Slack webhook:
gh secret set SLACK_WEBHOOK_URL
# Paste: https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Or Teams webhook:
gh secret set TEAMS_WEBHOOK_URL
# Paste: https://YOUR.webhook.office.com/...
```

### ✅ 3) Retention & Hygiene

**Status:** Implemented and deployed

**What was added:**

1. **Makefile target:**
   ```bash
   make tidy-retention
   ```
   - Cleans `.trash/` files >30 days
   - Removes `g/reports/proof/*_proof.md` >30 days
   - Smart counting and reporting

2. **GitHub Actions workflow:**
   - File: `.github/workflows/retention.yml`
   - Schedule: Daily at 09:05 ICT (02:05 UTC)
   - Auto-commits cleanup changes
   - Manual trigger available

3. **Documentation:**
   - File: `g/manuals/RETENTION_AND_ALERTS.md`
   - Complete setup guide
   - Troubleshooting steps
   - Configuration options

## Test Results

**Local test:**
```
make tidy-retention
🧹 Cleaning old files (>30 days)...
  .trash/: 0 files removed
  g/reports/proof/: 0 proof files removed
✅ No files to clean (nothing >30 days old)
```

**System status:**
```
Latest proof: g/reports/proof/251009_0653_proof.md
- Total files: 1311
- Out-of-zone files (root level): 7
- Max path depth: 13
```

## Workflows Deployed

1. **Daily Proof (Option C)** - active
2. **Daily Proof Alerting** - active
3. **Retention (proof + trash)** - active (new)

## Files Changed

**Modified:**
- `Makefile` - Added `tidy-retention` target

**Created:**
- `.github/workflows/retention.yml` - Automated cleanup workflow
- `g/manuals/RETENTION_AND_ALERTS.md` - Complete documentation

## Manual Commands

**Test retention:**
```bash
make tidy-retention
```

**Trigger manually:**
```bash
gh workflow run "Retention (proof + trash)"
```

**Check status:**
```bash
make status
```

**View workflow runs:**
```bash
gh run list --workflow=retention.yml --limit 5
gh run list --workflow=daily-proof-alerting.yml --limit 5
```

## Configuration Options

**Change retention period:**
Edit `Makefile`, change `-mtime +30` to desired days

**Change schedule:**
Edit `.github/workflows/retention.yml` cron expression

**Disable alerting:**
Remove webhook secrets:
```bash
gh secret remove SLACK_WEBHOOK_URL
gh secret remove TEAMS_WEBHOOK_URL
```

## Next Steps Available

From original ops menu:

**1) Project backfill** - Auto-group legacy reports via keyword map
**4) Agents spine** - Create agents/{clc,gg,gc,mary,paula}/README.md + index
**5) Boss daily HTML** - Auto-generate views/ops/daily/index.html

**Select option:** Reply with `1`, `4`, `5`, or combo like `"1,4"`

## Production Readiness

- ✅ Retention system tested locally
- ✅ Workflows deployed to main
- ✅ Documentation complete
- ⏸️ Alerts ready (pending webhook configuration)
- ✅ Manual override available (`make tidy-retention`)

## Commit Details

```
feat(ops): implement retention & hygiene system with CI alerts

- Added make tidy-retention target (cleans .trash/ and g/reports/proof/ >30d)
- Created retention.yml workflow (daily 09:05 ICT automated cleanup)
- Documented existing CI alerts system (daily-proof-alerting.yml)
- Added comprehensive manual: g/manuals/RETENTION_AND_ALERTS.md
```

**Commit:** b30b674
**Pushed:** main @ 2025-10-09 18:02
