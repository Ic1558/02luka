# Cron Jobs - 02luka System

## Digest Refresh (Phase 4 Automation)

**Script:** `digest_refresh.sh`
**Purpose:** Periodic fallback to refresh work_notes_digest.jsonl
**Interval:** Every 5 minutes

### Installation Options

#### Option 1: crontab (Traditional)

```bash
# Edit crontab
crontab -e

# Add this line:
*/5 * * * * ~/02luka/g/cron/digest_refresh.sh

# Verify
crontab -l
```

#### Option 2: launchd (macOS Recommended)

Create `~/Library/LaunchAgents/com.02luka.digest-refresh.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.digest-refresh</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/env</string>
        <string>zsh</string>
        <string>/Users/YOUR_USERNAME/02luka/g/cron/digest_refresh.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>StandardOutPath</key>
    <string>/tmp/digest-refresh.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/digest-refresh.err</string>
</dict>
</plist>
```

Load the agent:

```bash
launchctl load ~/Library/LaunchAgents/com.02luka.digest-refresh.plist
launchctl start com.02luka.digest-refresh
```

Verify:

```bash
launchctl list | grep digest-refresh
```

#### Option 3: Manual Periodic Run

If automated scheduling is not desired, run manually:

```bash
# Run once
~/02luka/g/cron/digest_refresh.sh

# Or add to your shell startup (~/.zshrc)
# (cd ~/02luka && g/cron/digest_refresh.sh &)
```

### Monitoring

Check if digest is being refreshed:

```bash
# Check digest modification time
ls -lh ~/02luka/g/core_state/work_notes_digest.jsonl

# Check cron logs (crontab)
grep digest /var/log/syslog

# Check launchd logs
tail -f /tmp/digest-refresh.log
```

### Uninstallation

**crontab:**
```bash
crontab -e
# Remove the digest_refresh line
```

**launchd:**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.digest-refresh.plist
rm ~/Library/LaunchAgents/com.02luka.digest-refresh.plist
```

---

## Notes

- This is a **fallback mechanism**; primary automation comes from file watcher and post-write hooks
- Safe to run multiple times (idempotent via `--incremental` flag)
- Failures are silently ignored (doesn't break the system)
