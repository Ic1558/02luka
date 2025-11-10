# Phase15 Quick Health - Go Live Checklist

**Date:** 2025-11-10 (ICT)  
**Status:** ✅ LaunchAgent Active | ⏸️ CI in Maintenance Mode

## ✅ Completed (2025-11-10)

### Local (macOS)
- [x] LaunchAgent plist copied to ~/Library/LaunchAgents/
- [x] Health check script tested
- [x] MLS integration tested
- [x] Status file created: `~/02luka/mls/status/phase15_quickhealth.json`
- [x] Health events logged to MLS ledger

### CI (GitHub Actions)
- [x] MAINTENANCE_MODE set to `1` (temporary)
- [x] Workflow file created: `.github/workflows/phase15-quick-health.yml`
- [ ] Workflow needs push to remote to be available

## ⏸️ Pending (2025-11-11 08:15 ICT)

### Remove Maintenance Mode
```bash
# Option 1: Delete variable (defaults to 0)
gh variable delete MAINTENANCE_MODE

# Option 2: Set to 0 explicitly
gh variable set MAINTENANCE_MODE --body "0"
```

### Verify First Scheduled Run
```bash
# Watch for scheduled run at 08:15 ICT
gh run list --workflow phase15-quick-health.yml --limit 5

# Download artifact
gh run download --name phase15-quick-health-json -D /tmp/phase15
jq . /tmp/phase15/health.json
```

## 📊 Current Status

### LaunchAgent
- **Service:** `com.02luka.phase15.quickhealth`
- **Schedule:** Every 10 minutes
- **Status:** ✅ Active (after push)
- **Output:** `~/02luka/mls/status/phase15_quickhealth.json`
- **Logs:** `~/Library/Logs/phase15_quickhealth.{log,err}`

### CI Workflow
- **File:** `.github/workflows/phase15-quick-health.yml`
- **Schedule:** Daily at 08:15 ICT (`cron: '15 1 * * *'`)
- **Status:** ⏸️ Maintenance Mode (MAINTENANCE_MODE=1)
- **Next Run:** 2025-11-11 08:15 ICT (after removing maintenance mode)

## 🔍 Monitoring

### Check LaunchAgent Status
```bash
launchctl list | grep com.02luka.phase15.quickhealth
launchctl print gui/$(id -u)/com.02luka.phase15.quickhealth | grep -E 'state|pid|LastExitStatus'
```

### View Latest Health Check
```bash
cat ~/02luka/mls/status/phase15_quickhealth.json | jq .
```

### View MLS Health Events
```bash
~/02luka/tools/mls_view.zsh --today --grep health
```

### Check CI Runs
```bash
gh run list --workflow phase15-quick-health.yml --limit 10
```

## 🚨 Troubleshooting

### LaunchAgent Not Running
```bash
# Restart LaunchAgent
launchctl bootout gui/$(id -u)/com.02luka.phase15.quickhealth 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.02luka.phase15.quickhealth.plist
launchctl kickstart -k gui/$(id -u)/com.02luka.phase15.quickhealth
```

### Status File Not Updating
```bash
# Check logs
tail -f ~/Library/Logs/phase15_quickhealth.log
tail -f ~/Library/Logs/phase15_quickhealth.err

# Manual run
~/02luka/tools/phase15_quick_health.zsh --json > ~/02luka/mls/status/phase15_quickhealth.json
```

### CI Workflow Not Running
```bash
# Check maintenance mode
gh variable list | grep MAINTENANCE_MODE

# Remove maintenance mode
gh variable delete MAINTENANCE_MODE

# Trigger manual run (after push)
gh workflow run phase15-quick-health.yml
```

## 📝 Next Steps

1. **Push to Remote:**
   ```bash
   git push origin fix/add-maintenance-guards
   ```

2. **Tomorrow (2025-11-11 08:15 ICT):**
   - Remove MAINTENANCE_MODE: `gh variable delete MAINTENANCE_MODE`
   - Monitor first scheduled run
   - Verify artifact upload

3. **Ongoing:**
   - Monitor LaunchAgent logs weekly
   - Review health check results in `~/02luka/mls/status/phase15_quickhealth.json`
   - Check MLS ledger for health events

---

**Last Updated:** 2025-11-10T22:30:00+0700  
**Next Review:** 2025-11-11 08:15 ICT (after first scheduled run)
