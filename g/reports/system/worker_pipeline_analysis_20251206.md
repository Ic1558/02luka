# Worker Pipeline Analysis - Why CLC Didn't Process WO

**Date:** 2025-12-06  
**WO:** WO-20251206-SANDBOX-FIX-V1  
**Issue:** Worker pipeline did not automatically process the WO

---

## Executive Summary

**Root Cause:** The CLC worker pipeline is **not running** as a background service. The WO was placed in `bridge/inbox/CLC/` but there is no active process monitoring that directory.

**Expected Flow:**
1. WO created in `bridge/inbox/CLC/WO-*.yaml`
2. CLC worker (`agents/clc_local/clc_local.py --watch-inbox CLC`) monitors directory
3. Worker picks up WO, processes it, moves to `bridge/processed/CLC/`

**Actual Flow:**
1. ✅ WO created in `bridge/inbox/CLC/WO-20251206-SANDBOX-FIX-V1.yaml`
2. ❌ **No worker process running** to monitor inbox
3. ⏳ WO remains in inbox, unprocessed
4. ✅ CLS manually completed the work instead

---

## Investigation Results

### 1. CLC Worker Capability

**File:** `agents/clc_local/clc_local.py`

**Capability Found:**
```python
def watch_inbox(inbox_name: str):
    """Monitors a Bridge inbox and processes new Work Order files."""
    inbox_path = PROJECT_ROOT / "bridge" / "inbox" / inbox_name
    # ... monitors directory, processes WOs ...
```

**Usage:**
```bash
python agents/clc_local/clc_local.py --watch-inbox CLC
```

**Status:** ✅ Code exists and can monitor inbox

---

### 2. LaunchAgent Status

**Search Results:**
- ✅ LaunchAgent files **DO exist**:
  - `com.02luka.clc-worker.plist`
  - `com.02luka.clc.local.plist`
  - `com.02luka.clc-bridge.plist`
- ✅ LaunchAgents **ARE registered**:
  - `com.02luka.clc-worker` (PID 78)
  - `com.02luka.clc_local` (PID 1013)
  - `com.02luka.clc.local` (exit code 127)
  - `com.02luka.clc-bridge` (exit code 0)

**Conclusion:** LaunchAgents exist and are registered, but may not be configured correctly or may not be watching the right inbox

---

### 3. Previous WO Processing

**Evidence of Past Success:**
- ✅ `bridge/processed/CLC/` contains 5 processed WOs:
  - `WO-20251113-CLS-WO-CLEANUP-BOT.yaml`
  - `WO-20251113-MLS-PROMPT-CAPTURE.yaml`
  - `WO-20251113-SYSTEM-TRUTH-SYNC.yaml`
  - `WO-20251115-SAVE-SH-MLS-INTEGRATION.yaml`
  - `WO-251112-014650-auto.yaml`

**Conclusion:** CLC worker **has worked before**, but is **not currently running**

---

### 4. Current WO Status

**Location:** `bridge/inbox/CLC/WO-20251206-SANDBOX-FIX-V1.yaml`

**Status:**
- ✅ File exists
- ✅ Valid YAML structure
- ✅ `strict_target: "CLC"` specified
- ❌ **Not processed** (still in inbox, not moved to processed/)

**Workaround:** CLS manually completed the work (10/10 score)

---

## Root Cause Analysis

### Why Worker Pipeline Is Not Working

**CRITICAL FINDING:** Worker **IS running**, but watching the **WRONG inbox**!

1. **Worker Running, Wrong Inbox**
   - ✅ LaunchAgent exists: `com.02luka.clc-worker.plist`
   - ✅ Worker process running (PID 78)
   - ✅ Another worker watching inbox (PID 1013)
   - ❌ **Watching `LIAM` inbox, not `CLC` inbox!**
   - Command: `python agents/clc_local/clc_local.py --watch-inbox LIAM`

2. **LaunchAgent Configuration Issue**
   - LaunchAgent runs: `agents.clc_local.clc_worker` (different module)
   - Not using: `clc_local.py --watch-inbox CLC`
   - May not have inbox watching capability

3. **Inbox Mismatch**
   - WO placed in: `bridge/inbox/CLC/`
   - Worker watching: `bridge/inbox/LIAM/`
   - Result: WO never processed

4. **No CLC-Specific Worker**
   - No dedicated worker for CLC inbox
   - Only LIAM inbox is being monitored
   - CLC WOs remain unprocessed

---

## Expected vs Actual Architecture

### Expected Architecture

```
┌─────────────────┐
│  WO Created     │
│  (bridge/inbox) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  CLC Worker     │◄─── LaunchAgent (auto-start)
│  (--watch-inbox)│     - Runs on boot
│                 │     - Monitors inbox
│                 │     - Processes WOs
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  WO Processed   │
│  (bridge/processed)│
└─────────────────┘
```

### Actual Architecture

```
┌─────────────────┐
│  WO Created     │
│  (bridge/inbox) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  CLC Worker     │◄─── ❌ NOT RUNNING
│  (--watch-inbox)│     - No LaunchAgent
│                 │     - Not started
│                 │     - No monitoring
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  WO Unprocessed │
│  (stays in inbox)│
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  CLS Manual     │◄─── Workaround
│  Implementation │     - Direct execution
│  (10/10 score)  │     - Bypasses worker
└─────────────────┘
```

---

## Recommendations

### Immediate Fix

1. **Fix LaunchAgent to Watch CLC Inbox**
   
   **Option A: Update existing LaunchAgent**
   - Modify `com.02luka.clc-worker.plist` to use:
     ```xml
     <string>agents/clc_local/clc_local.py</string>
     <string>--watch-inbox</string>
     <string>CLC</string>
     ```
   
   **Option B: Create new LaunchAgent for CLC**
   ```xml
   ~/Library/LaunchAgents/com.02luka.clc-inbox-watcher.plist
   ```
   - Run: `python agents/clc_local/clc_local.py --watch-inbox CLC`
   - KeepAlive: true
   - RunAtLoad: true
   - StandardOutPath: `~/02luka/logs/clc_inbox_watcher.out`
   - StandardErrorPath: `~/02luka/logs/clc_inbox_watcher.err`

2. **Reload LaunchAgent**
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.02luka.clc-worker.plist
   launchctl load ~/Library/LaunchAgents/com.02luka.clc-worker.plist
   # OR load new one
   launchctl load ~/Library/LaunchAgents/com.02luka.clc-inbox-watcher.plist
   ```

3. **Verify Worker Running and Watching CLC**
   ```bash
   launchctl list | grep clc
   ps aux | grep "watch-inbox CLC"
   ls -la ~/02luka/bridge/inbox/CLC/  # Should see WOs being processed
   ```

### Long-term Improvements

1. **Health Monitoring**
   - Add health check endpoint
   - Monitor worker process status
   - Auto-restart on failure

2. **WO Queue Management**
   - Add priority queue
   - Add retry mechanism
   - Add failure notifications

3. **Integration with CLS**
   - CLS can check worker status
   - CLS can trigger worker if needed
   - CLS can report worker failures

4. **Documentation**
   - Document worker setup process
   - Document troubleshooting steps
   - Add runbook for worker failures

---

## Verification Steps

### Check Worker Status

```bash
# 1. Check if LaunchAgent exists
ls -la ~/Library/LaunchAgents/com.02luka.clc-worker.plist

# 2. Check if worker is running
launchctl list | grep clc
ps aux | grep clc_local

# 3. Check inbox for unprocessed WOs
ls -la ~/02luka/bridge/inbox/CLC/

# 4. Check processed WOs
ls -la ~/02luka/bridge/processed/CLC/
```

### Test Worker Manually

```bash
# Start worker in foreground (for testing)
cd ~/02luka
python agents/clc_local/clc_local.py --watch-inbox CLC

# In another terminal, check if it's processing
tail -f ~/02luka/logs/clc_worker.out
```

---

## Summary

| Component | Status | Notes |
|-----------|--------|-------|
| **CLC Worker Code** | ✅ Exists | `agents/clc_local/clc_local.py` |
| **Watch Inbox Mode** | ✅ Implemented | `--watch-inbox CLC` |
| **LaunchAgent** | ✅ Exists | `com.02luka.clc-worker.plist` |
| **Worker Running** | ✅ Yes | PID 78, but wrong module |
| **Inbox Watched** | ❌ Wrong | Watching `LIAM`, not `CLC` |
| **WO Processing** | ❌ Failed | Wrong inbox monitored |
| **Previous Success** | ✅ Yes | 5 WOs processed before (different setup?) |

**Conclusion:** Worker pipeline **IS running**, but is **watching the wrong inbox** (`LIAM` instead of `CLC`). The LaunchAgent needs to be updated to watch the CLC inbox, or a new LaunchAgent needs to be created specifically for CLC inbox monitoring.

---

**Next Steps:**
1. Create LaunchAgent for CLC worker
2. Load and verify worker is running
3. Test with a new WO
4. Document setup process

---

**Report Generated:** 2025-12-06  
**Status:** ✅ Root Cause Identified - Missing LaunchAgent Configuration
