# Phase 1, Task 1.1: ram_guard.zsh - COMPLETE

**Date:** 2025-11-17  
**Status:** ✅ Implementation Complete, Ready for Testing

---

## Files Created

### 1. `config/safe_kill_list.txt`
**Purpose:** Initial conservative list of processes safe to kill during RAM crisis

**Contents:**
- Docker backend
- Browsers (Safari, Chrome)
- VSCode (redundant with Cursor)
- Mail/Media apps (non-critical)

**Location:** `~/02luka/config/safe_kill_list.txt`

---

### 2. `tools/ram_guard.zsh`
**Purpose:** Monitor swap/load/memory pressure every 60s, publish alerts to Redis

**Features:**
- ✅ Monitors swap usage via `sysctl vm.swapusage`
- ✅ Monitors load average via `sysctl vm.loadavg`
- ✅ Calculates swap percentage
- ✅ Publishes alerts to Redis channel `02luka:alerts:ram`
- ✅ Logs to `~/02luka/logs/ram_guard.log`
- ✅ Handles Redis connection failures gracefully
- ✅ Thresholds: Swap >75% = WARNING, >90% = CRITICAL

**Dependencies:**
- `jq` - JSON processing
- `bc` - Math calculations
- `redis-cli` - Redis pub/sub
- `sysctl` - System info (macOS built-in)

**Alert Format:**
```json
{
  "type": "ram_warning|ram_critical|load_warning",
  "severity": "warning|critical",
  "message": "Human-readable message",
  "swap_pct": 85,
  "swap_used_gb": 20.5,
  "swap_total_gb": 23.5,
  "load_avg": 8.5,
  "timestamp": "2025-11-17T02:30:00Z",
  "actions_taken": []
}
```

---

### 3. `LaunchAgents/com.02luka.ram.guard.plist`
**Purpose:** LaunchAgent to run `ram_guard.zsh` every 60 seconds

**Configuration:**
- **StartInterval:** 60 seconds
- **KeepAlive:** true (restart if crashes)
- **ThrottleInterval:** 60 seconds (prevent feedback loops)
- **Logs:** `~/02luka/logs/ram_guard.{stdout,stderr}.log`

---

## Testing Instructions

### Step 1: Manual Test
```bash
cd ~/02luka
tools/ram_guard.zsh
```

**Expected:**
- Logs current swap/load to `~/02luka/logs/ram_guard.log`
- If swap >75%, publishes alert to Redis
- No errors

### Step 2: Verify Redis Alert
```bash
# In another terminal, subscribe to Redis channel
redis-cli SUBSCRIBE 02luka:alerts:ram
```

**Expected:**
- Receives JSON alert if threshold breached
- Alert format matches specification

### Step 3: Check Logs
```bash
tail -f ~/02luka/logs/ram_guard.log
```

**Expected:**
- Timestamped log entries
- Swap percentage and load average logged
- Alerts logged when thresholds breached

### Step 4: Load LaunchAgent
```bash
# Copy plist to LaunchAgents directory
cp ~/02luka/LaunchAgents/com.02luka.ram.guard.plist ~/Library/LaunchAgents/

# Load LaunchAgent
launchctl load ~/Library/LaunchAgents/com.02luka.ram.guard.plist

# Verify it's running
launchctl list | grep com.02luka.ram.guard
```

**Expected:**
- LaunchAgent loaded successfully
- Shows in `launchctl list`
- Runs every 60 seconds

### Step 5: Verify Continuous Operation
```bash
# Wait 2 minutes, then check logs
sleep 120
tail -20 ~/02luka/logs/ram_guard.log
```

**Expected:**
- Multiple log entries (one per minute)
- Consistent swap/load reporting
- No errors

---

## Verification Checklist

- [ ] `ram_guard.zsh` syntax valid (`zsh -n`)
- [ ] Manual run succeeds
- [ ] Logs written correctly
- [ ] Redis alerts published (if threshold breached)
- [ ] LaunchAgent loads successfully
- [ ] LaunchAgent runs every 60s
- [ ] No errors in stderr log

---

## Known Issues / Limitations

1. **Swap Calculation:**
   - Uses `sysctl vm.swapusage` (macOS-specific)
   - Parses output with `sed` (may need adjustment if format changes)

2. **Dependencies:**
   - Requires `jq`, `bc`, `redis-cli`
   - Fails gracefully if Redis unavailable

3. **Load Average:**
   - Only checks 1-minute load average
   - May need 5/15-minute averages for better trend analysis

---

## Next Steps

### Immediate:
1. Test `ram_guard.zsh` manually
2. Verify Redis alerts
3. Load LaunchAgent
4. Monitor for 24 hours

### Phase 1, Task 1.2:
- Create `tools/process_watchdog.zsh` (45 min)
- Track processes >500MB, detect memory leaks

### Phase 1, Task 1.3:
- Create `tools/agent_health_monitor.zsh` (45 min)
- Detect crash loops and log bloat

---

**Status:** ✅ Ready for Testing  
**Next Task:** Test ram_guard.zsh, then proceed to Task 1.2
