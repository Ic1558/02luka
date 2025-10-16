# OPS Monitoring CI/CD Guide

**Last Updated:** 2025-10-16
**Workflow:** `.github/workflows/ops-monitoring.yml`
**Status:** ✅ READY FOR DEPLOYMENT

---

## Overview

The OPS Monitoring workflow automates the execution of `ops_atomic.sh` in GitHub Actions, providing continuous system health monitoring with artifact uploads and optional Discord notifications.

---

## Features

✅ **Scheduled Execution** - Runs every 6 hours automatically
✅ **Manual Trigger** - On-demand execution via GitHub UI
✅ **Artifact Upload** - Saves reports for 30 days
✅ **Status Checking** - Fails workflow if OPS status is "fail"
✅ **Discord Integration** - Optional webhook notifications
✅ **Mock Services** - Starts API server for health checks in CI

---

## Workflow Configuration

### Triggers

```yaml
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:  # Manual trigger
  # push:
  #   branches: [main]  # Optional: run on push
```

**Schedule Times (UTC):**
- 00:00, 06:00, 12:00, 18:00

**To enable push trigger:**
Uncomment the `push` section in `.github/workflows/ops-monitoring.yml`

### Timeout

- **Workflow timeout:** 15 minutes
- **Individual step timeouts:** Inherit from workflow

---

## Required Secrets

### Optional Secrets (for Discord notifications)

Add these in **Settings → Secrets and variables → Actions**:

| Secret | Description | Example |
|--------|-------------|---------|
| `DISCORD_WEBHOOK_DEFAULT` | Default Discord webhook URL | `https://discord.com/api/webhooks/...` |
| `DISCORD_WEBHOOK_MAP` | JSON mapping of channel webhooks | `{"ops":"https://...","alerts":"https://..."}` |
| `REPORTBOT_REPORT_BASE_URL` | Base URL for report links | `https://ic1558.github.io/02luka/reports/` |

**Note:** Workflow runs successfully without these secrets (notifications skipped).

---

## Jobs

### Job 1: `ops-atomic`

**Purpose:** Run OPS atomic tests and generate reports

**Steps:**
1. **Checkout repository** - Clone repo with full history
2. **Setup Node.js** - Install Node.js 20
3. **Install dependencies** - jq, curl
4. **Start mock services** - API server for health checks
5. **Run OPS Atomic** - Execute `./run/ops_atomic.sh`
6. **Parse OPS summary** - Extract status, PASS/WARN/FAIL counts
7. **Upload reports** - Save artifacts for 30 days
8. **Check OPS status** - Fail if status is "fail"
9. **Cleanup** - Stop mock services

**Artifacts Created:**
- `ops-reports-{run_id}/OPS_ATOMIC_*.md` - Detailed report
- `ops-reports-{run_id}/OPS_SUMMARY.json` - JSON summary

### Job 2: `notify-discord`

**Purpose:** Send Discord notification with results

**Runs:** Always after `ops-atomic` (success or failure)

**Requires:** `DISCORD_WEBHOOK_DEFAULT` secret configured

**Steps:**
1. **Checkout repository**
2. **Download reports** - Fetch artifacts from job 1
3. **Send Discord notification** - POST to webhook with summary

**Notification Format:**
```
🤖 **OPS Monitoring (GitHub Actions)**

Status: PASS
PASS=4 WARN=0 FAIL=0

Run: https://github.com/Ic1558/02luka/actions/runs/123456789
```

---

## Usage

### Manual Trigger

1. Navigate to **Actions → OPS Monitoring**
2. Click **Run workflow** dropdown
3. Select branch (default: main)
4. Click **Run workflow** button

### View Results

**During Run:**
1. Go to **Actions** tab
2. Click on workflow run
3. Expand job steps to see real-time logs

**After Run:**
1. Scroll to **Artifacts** section
2. Download `ops-reports-{run_id}` ZIP
3. Extract and read `OPS_ATOMIC_*.md` and `OPS_SUMMARY.json`

### Check Status

**Workflow succeeds if:**
- OPS atomic completes with status "pass" or "warn"
- No critical failures detected

**Workflow fails if:**
- OPS atomic returns status "fail"
- FAIL count > 0 in summary

---

## Troubleshooting

### Error: "API server not ready"

**Symptom:** Workflow times out waiting for API server

**Fix:**
```yaml
# Increase wait time in workflow
for i in {1..60}; do  # Change from 30 to 60
  # ...
done
```

### Error: "OPS_SUMMARY.json not found"

**Symptom:** Workflow reports unknown status

**Diagnosis:**
- Check if `reportbot` ran successfully
- Verify `g/reports/` directory exists

**Fix:**
```bash
# Add debug step before "Parse OPS summary"
- name: Debug reports directory
  run: ls -la g/reports/
```

### Error: "Discord notification failed"

**Symptom:** Job `notify-discord` shows error

**Diagnosis:**
- Check if `DISCORD_WEBHOOK_DEFAULT` is configured
- Verify webhook URL is valid

**Fix:**
1. Test webhook manually:
   ```bash
   curl -X POST "$DISCORD_WEBHOOK_DEFAULT" \
     -H "Content-Type: application/json" \
     -d '{"content":"Test from 02LUKA"}'
   ```
2. Update secret with correct URL

### Workflow doesn't trigger on schedule

**Possible Causes:**
1. Repository is private and no Actions quota
2. Schedule CRON syntax error
3. Workflow file has YAML errors

**Fix:**
1. Check Actions quota: **Settings → Billing**
2. Validate CRON: https://crontab.guru/#0_*/6_*_*_*
3. Validate YAML: Use online validator

---

## Customization

### Change Schedule Frequency

**Every 3 hours:**
```yaml
on:
  schedule:
    - cron: '0 */3 * * *'
```

**Daily at 8 AM UTC:**
```yaml
on:
  schedule:
    - cron: '0 8 * * *'
```

**Weekdays only at 9 AM UTC:**
```yaml
on:
  schedule:
    - cron: '0 9 * * 1-5'
```

### Add Slack Notifications

**Replace Discord step with:**
```yaml
- name: Send Slack notification
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  if: env.SLACK_WEBHOOK_URL != ''
  run: |
    STATUS=$(jq -r '.status' g/reports/OPS_SUMMARY.json)
    SUMMARY=$(jq -r '.summary' g/reports/OPS_SUMMARY.json)

    curl -X POST "$SLACK_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"OPS Status: ${STATUS}\\n${SUMMARY}\"}"
```

### Enable Push Trigger

**Uncomment in workflow:**
```yaml
on:
  schedule:
    - cron: '0 */6 * * *'
  workflow_dispatch:
  push:  # ← Uncomment
    branches: [main]  # ← Uncomment
```

### Add Email Notifications

**Use GitHub Actions mailer:**
```yaml
- name: Send email on failure
  if: failure()
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 465
    username: ${{ secrets.MAIL_USERNAME }}
    password: ${{ secrets.MAIL_PASSWORD }}
    subject: OPS Monitoring Failed
    to: ops@example.com
    from: github-actions@example.com
    body: |
      OPS monitoring workflow failed.
      Run: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

---

## Integration with Other Workflows

### Block PR merges on OPS failures

**Add to `.github/workflows/ci.yml`:**
```yaml
jobs:
  check-ops-status:
    runs-on: ubuntu-latest
    steps:
      - name: Download latest OPS report
        uses: dawidd6/action-download-artifact@v2
        with:
          workflow: ops-monitoring.yml
          name: ops-reports-*
          path: reports/

      - name: Check OPS status
        run: |
          STATUS=$(jq -r '.status' reports/OPS_SUMMARY.json)
          if [ "$STATUS" = "fail" ]; then
            echo "Cannot merge: OPS status is FAIL"
            exit 1
          fi
```

### Trigger on deployment

**Add to deployment workflow:**
```yaml
jobs:
  deploy:
    # ... deployment steps ...

  verify-deployment:
    needs: deploy
    runs-on: ubuntu-latest
    steps:
      - name: Trigger OPS monitoring
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.actions.createWorkflowDispatch({
              owner: context.repo.owner,
              repo: context.repo.repo,
              workflow_id: 'ops-monitoring.yml',
              ref: 'main'
            })
```

---

## Metrics & Monitoring

### Key Metrics to Track

1. **Workflow Success Rate** - % of runs with PASS status
2. **Mean Time to Detection** - Time from issue to alert
3. **False Positive Rate** - WARN/FAIL without actual issues
4. **Artifact Size Growth** - Monitor storage usage

### GitHub Insights

**View workflow stats:**
1. Go to **Actions → OPS Monitoring**
2. See success/failure rate over time
3. Click **...** → **View workflow file**

### Export Metrics

**Use GitHub API:**
```bash
gh api repos/Ic1558/02luka/actions/workflows/ops-monitoring.yml/runs \
  --jq '.workflow_runs[] | {id, status, conclusion, created_at}'
```

---

## Cost Estimation

### GitHub Actions Minutes

**Per execution:** ~5-10 minutes
**Schedule:** 4 times/day
**Monthly usage:** 4 × 30 × 10 = 1,200 minutes

**Free tier:** 2,000 minutes/month (public repos)
**Cost if exceeded:** $0.008/minute = $9.60/month (private repos)

### Storage

**Per artifact:** ~50 KB (reports)
**Retention:** 30 days
**Monthly storage:** 4 × 30 × 50 KB = 6 MB

**Free tier:** 500 MB
**Cost if exceeded:** Negligible

---

## Best Practices

1. ✅ **Test manually first** - Use workflow_dispatch before enabling schedule
2. ✅ **Monitor initially** - Check first few scheduled runs for issues
3. ✅ **Set up notifications** - Configure Discord/Slack webhooks
4. ✅ **Review artifacts** - Periodically download and inspect reports
5. ✅ **Adjust frequency** - Balance monitoring needs vs. Actions quota
6. ✅ **Document changes** - Update this guide when modifying workflow
7. ✅ **Use secrets** - Never hardcode webhooks or tokens

---

## Rollback Plan

**If workflow causes issues:**

1. **Disable workflow:**
   ```bash
   gh workflow disable ops-monitoring.yml
   ```

2. **Revert workflow file:**
   ```bash
   git revert <commit-sha>
   git push origin main
   ```

3. **Delete workflow (if needed):**
   ```bash
   rm .github/workflows/ops-monitoring.yml
   git commit -m "chore: remove ops-monitoring workflow"
   git push
   ```

---

## Related Documentation

- [Alerts Setup Manual](./alerts_setup.md) - Reportbot configuration
- [Deployment Report](../reports/DEPLOYMENT_REPORTBOT_251016.md) - Phase 5 deployment
- [OPS Atomic Script](../../run/ops_atomic.sh) - Core testing script
- [GitHub Actions Docs](https://docs.github.com/en/actions) - Official documentation

---

## Support & Feedback

**Issues:** Report workflow problems in GitHub Issues with label `ci/cd`

**Questions:** Tag `@CLC` in discussions

**Improvements:** Submit PRs with workflow enhancements

---

**End of OPS Monitoring CI/CD Guide**
