# Code Review: MLS Auto-Update Issue

**Date:** 2025-11-15  
**Issue:** MLS ledger and status not auto-updating  
**Reviewer:** CLS (Automated + Manual Review)  
**Scope:** MLS cursor watcher, auto-record script, LaunchAgent configuration

---

## 1. Style Check

### ✅ Strengths
- **Clear structure:** `mls_cursor_watcher.zsh` has well-defined functions
- **Error handling:** Uses try/catch patterns and error logging
- **Path management:** Uses `LUKA_SOT` environment variable correctly
- **Logging:** Comprehensive logging to stdout/stderr files

### ⚠️ Issues Found
- **LaunchAgent KeepAlive:** Set to `false` - may cause watcher to stop after errors
- **ThrottleInterval:** Set to 30 seconds - may be too aggressive
- **No health check:** No mechanism to verify watcher is actually running
- **Silent failures:** Errors may not be visible if LaunchAgent stops

---

## 2. History-Aware Review

### Context
- **Previous state:** MLS auto-update was working (based on ledger entries from 2025-11-13)
- **Current state:** Latest ledger entry is from 2025-11-14 (yesterday)
- **Issue:** No new entries being captured automatically

### Related Components
- **`mls_cursor_watcher.zsh`:** Monitors Cursor IDE for prompts and captures them
- **`mls_auto_record.zsh`:** Records prompts to MLS ledger
- **LaunchAgent:** `com.02luka.mls.cursor.watcher.plist` - runs watcher periodically
- **Ledger files:** `mls/ledger/YYYY-MM-DD.jsonl` - stores captured entries

### Recent Changes
- LaunchAgent was reloaded in previous session
- Watcher script exists and is executable
- Auto-record script exists

---

## 3. Obvious-Bug Scan

### 🔴 Critical Issues

1. **LaunchAgent KeepAlive: false**
   ```xml
   <key>KeepAlive</key>
   <false/>
   ```
   - **Problem:** If the watcher crashes or exits, LaunchAgent won't restart it
   - **Impact:** Watcher may have stopped and not restarted
   - **Fix:** Set `KeepAlive` to `true` for long-running watchers

2. **No Process Verification**
   - **Problem:** No check to verify watcher process is actually running
   - **Impact:** Watcher may have exited silently
   - **Fix:** Add health check or monitoring

### ⚠️ Medium Issues

1. **ThrottleInterval: 30 seconds**
   - **Problem:** May be too short, causing excessive CPU usage
   - **Impact:** LaunchAgent may throttle too aggressively
   - **Recommendation:** Increase to 60-120 seconds

2. **StartInterval: 300 seconds (5 minutes)**
   - **Problem:** Watcher runs every 5 minutes, but may miss rapid prompts
   - **Impact:** Some prompts may not be captured
   - **Recommendation:** Consider event-driven approach instead of polling

3. **Error Handling in Watcher**
   - **Problem:** Errors may cause script to exit without logging
   - **Impact:** Silent failures
   - **Fix:** Add try/catch around main logic

### 🟢 Low Issues

1. **No Status File Update**
   - **Problem:** No mechanism to update MLS status file
   - **Impact:** Status may be stale
   - **Note:** Status file location not found in codebase

2. **Log Rotation**
   - **Problem:** Logs may grow indefinitely
   - **Impact:** Disk space issues over time
   - **Recommendation:** Add log rotation

---

## 4. Risk Summary

### 🔴 High Risk
- **LaunchAgent KeepAlive: false** - Watcher may have stopped and not restarted
  - **Impact:** High (auto-update completely broken)
  - **Likelihood:** High (if watcher crashed)
  - **Fix:** Set KeepAlive to true

### 🟡 Medium Risk
1. **No Health Monitoring**
   - **Impact:** Medium (can't detect if watcher is down)
   - **Likelihood:** Medium
   - **Fix:** Add health check script or monitoring

2. **Silent Failures**
   - **Impact:** Medium (errors not visible)
   - **Likelihood:** Medium
   - **Fix:** Improve error logging and notification

### 🟢 Low Risk
1. **ThrottleInterval too short**
2. **No log rotation**
3. **Status file not updated**

---

## 5. Diff Hotspots

### Key Files to Review

1. **`LaunchAgents/com.02luka.mls.cursor.watcher.plist`**
   - **Line 25:** `KeepAlive` set to `false` (should be `true`)
   - **Line 23:** `StartInterval` set to `300` (5 minutes)
   - **Line 29:** `ThrottleInterval` set to `30` (may be too short)

2. **`tools/mls_cursor_watcher.zsh`**
   - **Main logic:** Watches Cursor IDE for prompts
   - **Error handling:** May exit on errors
   - **Logging:** Logs to files, but may not be checked

3. **`tools/mls_auto_record.zsh`**
   - **Function:** Records prompts to ledger
   - **Dependencies:** Requires ledger directory to exist

---

## 6. Root Cause Analysis

### Why Auto-Update Stopped

**Most Likely Causes:**

1. **LaunchAgent KeepAlive: false** (HIGH PROBABILITY)
   - Watcher crashed or exited
   - LaunchAgent didn't restart it
   - Result: No new entries captured

2. **Watcher Process Not Running** (MEDIUM PROBABILITY)
   - Process may have exited
   - No monitoring to detect this
   - Result: Silent failure

3. **Cursor IDE Not Detected** (LOW PROBABILITY)
   - Watcher may not be detecting Cursor IDE
   - Path or detection logic may be broken
   - Result: No prompts captured

4. **Auto-Record Script Failure** (LOW PROBABILITY)
   - Script may be failing silently
   - Permissions or path issues
   - Result: Captures fail to write

### Verification Steps

1. **Check LaunchAgent Status:**
   ```bash
   launchctl list | grep mls
   ```

2. **Check Watcher Process:**
   ```bash
   ps aux | grep mls_cursor_watcher
   ```

3. **Check Logs:**
   ```bash
   tail -f logs/mls_cursor_watcher.out.log
   tail -f logs/mls_cursor_watcher.err.log
   ```

4. **Test Auto-Record:**
   ```bash
   tools/mls_auto_record.zsh "test" "Test entry" "test,manual" ""
   ```

---

## 7. Recommended Fixes

### Priority 1: Critical

1. **Fix LaunchAgent KeepAlive**
   ```xml
   <key>KeepAlive</key>
   <true/>
   ```
   - **Why:** Ensures watcher restarts if it crashes
   - **Impact:** High - fixes auto-restart issue

2. **Add Health Check**
   - Create monitoring script to verify watcher is running
   - Alert if watcher process not found
   - **Impact:** Medium - enables detection of failures

### Priority 2: Important

3. **Improve Error Handling**
   - Add try/catch around main watcher logic
   - Log all errors to stderr log
   - **Impact:** Medium - prevents silent failures

4. **Increase ThrottleInterval**
   ```xml
   <key>ThrottleInterval</key>
   <integer>60</integer>
   ```
   - **Why:** Reduces CPU usage and throttling issues
   - **Impact:** Low - performance improvement

### Priority 3: Nice to Have

5. **Add Status File Update**
   - Create mechanism to update MLS status file
   - Include last capture time, entry count, etc.
   - **Impact:** Low - improves observability

6. **Add Log Rotation**
   - Rotate logs when they exceed size limit
   - Keep last N log files
   - **Impact:** Low - prevents disk space issues

---

## 8. Testing Plan

### Immediate Tests

1. **Check Current Status:**
   ```bash
   # Check LaunchAgent
   launchctl list | grep mls
   
   # Check process
   ps aux | grep mls_cursor_watcher
   
   # Check logs
   tail -20 logs/mls_cursor_watcher.out.log
   tail -20 logs/mls_cursor_watcher.err.log
   ```

2. **Test Auto-Record:**
   ```bash
   tools/mls_auto_record.zsh "test" "Manual test entry" "test,manual" ""
   ```

3. **Verify Ledger Update:**
   ```bash
   tail -1 mls/ledger/$(date +%Y-%m-%d).jsonl
   ```

### After Fixes

1. **Reload LaunchAgent:**
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist
   launchctl load ~/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist
   ```

2. **Monitor for 10 minutes:**
   ```bash
   tail -f logs/mls_cursor_watcher.out.log
   ```

3. **Verify New Entries:**
   ```bash
   watch -n 5 'tail -1 mls/ledger/$(date +%Y-%m-%d).jsonl'
   ```

---

## 9. Final Verdict

### 🔴 **CRITICAL ISSUE IDENTIFIED - IMMEDIATE FIX REQUIRED**

**Root Cause:** LaunchAgent cannot find script file - stderr shows "can't open input file"

**Evidence:**
- Stderr logs: `zsh: can't open input file: /Users/icmini/02luka/tools/mls_cursor_watcher.zsh`
- LaunchAgent is loaded but failing to execute
- No watcher process running
- Latest ledger entry: 2025-11-14 (yesterday)

**Secondary Issue:** LaunchAgent `KeepAlive` set to `false` - even if fixed, won't restart after crashes

**Reasoning:**
1. **KeepAlive: false** is the primary issue - watcher won't auto-restart
2. **No health monitoring** - can't detect if watcher is down
3. **Silent failures** - errors may not be visible
4. **Status file** - mechanism not found in codebase (may not exist)

**Immediate Actions:**
1. 🔴 **Fix script path issue** (verify file exists and is executable)
2. 🔴 **Fix LaunchAgent KeepAlive** (set to `true`)
3. ✅ **Reload LaunchAgent** (apply changes)
4. ✅ **Verify watcher is running** (check process)
5. ✅ **Monitor logs** (verify captures are working)
6. ⚠️ **Investigate status file** (if it exists, add update mechanism)

**Expected Outcome:**
- Watcher will auto-restart if it crashes
- New MLS entries will be captured automatically
- Status will be visible in logs

---

**Review Complete:** 2025-11-15  
**Reviewer:** CLS (Automated + Manual Review)  
**Verdict:** ⚠️ **CRITICAL ISSUE - KEEPALIVE SET TO FALSE**
