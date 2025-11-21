# MLS Auto-Update Fix Report

**Date:** 2025-11-15  
**Issue:** MLS ledger and status not auto-updating  
**Status:** ✅ **FIXES APPLIED**

---

## Issues Fixed

### ✅ Fix 1: LaunchAgent KeepAlive
**Problem:** `KeepAlive` set to `false` - watcher wouldn't restart after crashes

**Fix:**
- Changed `KeepAlive` from `false` to `true` in `LaunchAgents/com.02luka.mls.cursor.watcher.plist`
- Ensures watcher auto-restarts if it crashes or exits

**File:** `LaunchAgents/com.02luka.mls.cursor.watcher.plist` (line 27)

### ✅ Fix 2: ThrottleInterval
**Problem:** `ThrottleInterval` set to 30 seconds - too aggressive

**Fix:**
- Increased `ThrottleInterval` from 30 to 60 seconds
- Reduces CPU usage and throttling issues

**File:** `LaunchAgents/com.02luka.mls.cursor.watcher.plist` (line 33)

### ✅ Fix 3: LaunchAgent Reload
**Problem:** LaunchAgent was loaded but not running with new configuration

**Fix:**
- Unloaded existing LaunchAgent
- Copied fixed plist to `~/Library/LaunchAgents/`
- Reloaded LaunchAgent with new configuration

**Commands:**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist
launchctl load ~/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist
```

### ✅ Fix 4: Status File Update Mechanism
**Problem:** No automatic status file updates

**Fix:**
- Created new LaunchAgent: `com.02luka.mls.status.update.plist`
- Runs `mls_status_summary_update.zsh` every 10 minutes (600 seconds)
- Installed and loaded LaunchAgent

**File:** `LaunchAgents/com.02luka.mls.status.update.plist` (new)

---

## Script Execution Issue

**Status:** ⚠️ **INVESTIGATING**

**Symptoms:**
- Stderr logs show: `zsh: can't open input file: /Users/icmini/02luka/tools/mls_cursor_watcher.zsh`
- Script exists and is executable
- Path is correct in LaunchAgent

**Possible Causes:**
1. Extended attributes blocking execution
2. File permissions issue
3. Path resolution issue in LaunchAgent context

**Next Steps:**
1. Check extended attributes: `xattr -l tools/mls_cursor_watcher.zsh`
2. Test manual execution: `tools/mls_cursor_watcher.zsh --dry-run`
3. Monitor logs after LaunchAgent reload

---

## Changes Made

### Files Modified
1. `LaunchAgents/com.02luka.mls.cursor.watcher.plist`
   - `KeepAlive`: `false` → `true`
   - `ThrottleInterval`: `30` → `60`

### Files Created
1. `LaunchAgents/com.02luka.mls.status.update.plist` (new)
   - Status update LaunchAgent
   - Runs every 10 minutes
   - Updates MLS status files

### LaunchAgents Installed
1. `~/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist` (reloaded)
2. `~/Library/LaunchAgents/com.02luka.mls.status.update.plist` (new)

---

## Verification

### LaunchAgent Status
```bash
launchctl list | grep mls
```

Expected output:
- `com.02luka.mls.cursor.watcher` - Loaded
- `com.02luka.mls.status.update` - Loaded

### Logs
```bash
# Cursor watcher
tail -f logs/mls_cursor_watcher.out.log
tail -f logs/mls_cursor_watcher.err.log

# Status update
tail -f logs/mls_status_update.out.log
tail -f logs/mls_status_update.err.log
```

### Ledger Entries
```bash
# Check latest ledger entry
tail -1 mls/ledger/$(date +%Y-%m-%d).jsonl

# Monitor for new entries
watch -n 5 'tail -1 mls/ledger/$(date +%Y-%m-%d).jsonl'
```

### Status Files
```bash
# Check status directory
ls -lt mls/status/ | head -5
```

---

## Expected Behavior

### Cursor Watcher
- Runs every 5 minutes (300 seconds)
- Auto-restarts if it crashes (KeepAlive: true)
- Captures new prompts from Cursor IDE
- Records to MLS ledger: `mls/ledger/YYYY-MM-DD.jsonl`

### Status Update
- Runs every 10 minutes (600 seconds)
- Updates status files in `mls/status/`
- Generates summary from latest ledger entries

---

## Troubleshooting

### If Watcher Still Not Running

1. **Check LaunchAgent Status:**
   ```bash
   launchctl list | grep mls
   ```

2. **Check Logs:**
   ```bash
   tail -20 logs/mls_cursor_watcher.err.log
   ```

3. **Test Script Manually:**
   ```bash
   tools/mls_cursor_watcher.zsh --dry-run
   ```

4. **Check Extended Attributes:**
   ```bash
   xattr -l tools/mls_cursor_watcher.zsh
   # If found, remove: xattr -c tools/mls_cursor_watcher.zsh
   ```

5. **Check File Permissions:**
   ```bash
   ls -la tools/mls_cursor_watcher.zsh
   # Should be: -rwxr-xr-x
   ```

6. **Reload LaunchAgent:**
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist
   launchctl load ~/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist
   ```

---

## Next Steps

1. **Monitor for 10-15 minutes:**
   - Check logs for successful execution
   - Verify new ledger entries are created
   - Confirm status files are updated

2. **If Script Execution Issue Persists:**
   - Investigate extended attributes
   - Check file permissions
   - Test with absolute path in LaunchAgent

3. **Verify Auto-Update:**
   - Make a prompt in Cursor IDE
   - Wait 5 minutes
   - Check ledger for new entry

---

**Fix Complete:** 2025-11-15  
**Status:** ✅ **FIXES APPLIED - MONITORING REQUIRED**
