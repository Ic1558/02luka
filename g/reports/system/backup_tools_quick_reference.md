# Backup Tools Quick Reference

**Created:** 2025-12-08
**Purpose:** Time Machine + rsync backup management tools

---

## 🛠️ Available Tools

### 1. Time Machine Status Monitor
```bash
~/02luka/tools/tm_status.zsh
```

**Shows:**
- TM destination and mount status
- Last backup time
- Quota usage (with color-coded alerts)
- Snapshot count (oldest/newest)
- Overall health

**Use when:** Quick check if TM is working

---

### 2. Local Snapshot Cleanup
```bash
~/02luka/tools/tm_cleanup_local.zsh
```

**Purpose:** Free up space on Macintosh HD by removing local APFS snapshots

**Safe to use:**
- Only removes local snapshots (not ORICO backups)
- Interactive confirmation required
- Shows space before/after

**Use when:** Macintosh HD is running low on space

---

### 3. ORICO Quota Monitor
```bash
~/02luka/tools/orico_quota_check.zsh
```

**Shows:**
- Current quota usage (with color alerts)
- 🟢 < 80% = Healthy
- 🟡 80-90% = Warning
- 🔴 > 90% = Critical
- Breakdown of TM vs other files
- Logs to `g/telemetry/orico_quota.jsonl`

**Use when:** Check ORICO disk space

---

### 4. Backup Integrity Verification (MOST IMPORTANT)
```bash
~/02luka/tools/verify_backups.zsh
```

**Checks:**
- **Time Machine:**
  - Destination mounted?
  - Last backup < 24 hours?
  - Quota not full?
  - Encryption working?

- **rsync Backup:**
  - lukadata mounted?
  - Last backup < 24 hours?
  - Latest snapshot exists?
  - 7-day rotation working?

**Exit codes:**
- 0 = All healthy ✅
- 1 = Warning ⚠️
- 2 = Critical ❌

**Use when:**
- Daily health check (can be LaunchAgent)
- Before important work
- After system updates

---

## 📋 Recommended Usage

### Daily Routine
```bash
# Morning check
~/02luka/tools/verify_backups.zsh

# If all green, you're done!
# If warnings, investigate with:
~/02luka/tools/tm_status.zsh
~/02luka/tools/orico_quota_check.zsh
```

### Weekly Maintenance
```bash
# Check quota
~/02luka/tools/orico_quota_check.zsh

# Clean local snapshots if Macintosh HD is low on space
~/02luka/tools/tm_cleanup_local.zsh
```

### Troubleshooting
```bash
# If TM isn't working:
~/02luka/tools/tm_status.zsh  # Detailed status

# If ORICO is full:
~/02luka/tools/orico_quota_check.zsh  # Check usage
# Time Machine will auto-delete old snapshots

# If rsync is old:
~/02luka/tools/nas_backup.zsh  # Manual rsync backup
```

---

## 🔗 Integration Options

### Add to Daily Health Check (LaunchAgent)
```bash
# Add to existing health check or create new LaunchAgent
# Call verify_backups.zsh with exit code checking
```

### Add to Shell Aliases
```bash
# Add to ~/.zshrc
alias backup-status='~/02luka/tools/verify_backups.zsh'
alias backup-tm='~/02luka/tools/tm_status.zsh'
alias backup-quota='~/02luka/tools/orico_quota_check.zsh'
```

### Add to Claude Commands
```bash
# Create .claude/commands/backup.md
# Content: Run ~/02luka/tools/verify_backups.zsh
```

---

## 📊 Telemetry

**ORICO quota monitoring** logs to:
```
~/02luka/g/telemetry/orico_quota.jsonl
```

**Format:**
```json
{
  "ts": "2025-12-08T15:00:00Z",
  "volume": "TM_ORICO",
  "total": "600 GB",
  "used": "245 GB",
  "available": "355 GB",
  "percent": 40.8,
  "status": "healthy"
}
```

**Query examples:**
```bash
# Show last 10 quota checks
tail -10 ~/02luka/g/telemetry/orico_quota.jsonl | jq '.'

# Show trend over time
cat ~/02luka/g/telemetry/orico_quota.jsonl | jq -r '[.ts, .percent] | @csv'
```

---

## 🎯 Expected Behavior

### Normal (Healthy) State
```bash
$ ~/02luka/tools/verify_backups.zsh

=== Backup System Health Check ===
Time: 2025-12-08 15:00:00

[Time Machine]
  ✅ Destination: TM_ORICO mounted
  ✅ Last backup: 2 hours ago
  ✅ Quota: 40% used (healthy)
  ✅ Encryption: Active

[rsync Backup]
  ✅ Destination: lukadata mounted
  ✅ Last backup: 14 hours ago
  ✅ Latest: 20251208/
  ✅ Rotation: 7 days kept

[Overall]
  ✅ All systems operational

Next actions: None required
```

### Warning State
- Last backup 1-2 days old
- Quota 80-90% full
- Encryption not enabled

**Action:** Monitor, run manual backup if needed

### Critical State
- Destination not mounted
- Last backup > 2 days old
- Quota > 90% full

**Action:** Immediate attention required

---

## 📝 Notes

**Time Machine behavior:**
- Runs hourly automatically
- Auto-deletes old snapshots when quota full
- Local snapshots created on Macintosh HD
- Encryption protects backups (remember password!)

**rsync behavior:**
- Runs daily at 2 AM (LaunchAgent)
- Keeps 7 days of snapshots
- Hard-link deduplication (space efficient)
- Can run manually: `~/02luka/tools/nas_backup.zsh`

**Two separate systems:**
- Time Machine = System-level, versioned
- rsync = File-level, 7-day rotation
- They don't conflict or interfere

---

**Created by:** CLC
**Date:** 2025-12-08
**Related:** NAS_BACKUP_NEXT_STEPS.md
