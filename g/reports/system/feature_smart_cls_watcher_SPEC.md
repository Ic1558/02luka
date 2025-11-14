# Feature SPEC: Smart CLS Watcher

**Date:** 2025-11-15  
**Feature:** Smart CLS Watcher with Heartbeat Detection  
**Type:** Tool / Monitoring  
**Target:** CLS/Cursor IDE monitoring

---

## 1. Problem Statement

Current CLS monitoring lacks:
- Heartbeat detection (waits for real activity before alerting)
- macOS notifications for alerts
- Auto-kill capability with cooldown protection
- Persistent logging for troubleshooting
- Simple entrypoint (`check-cls` command)

**Goal:** Create a smart watcher that:
- Waits for actual CLS heartbeat before considering it "alive"
- Sends macOS notifications when CLS freezes
- Can auto-kill CLS/Cursor with cooldown to prevent kill spam
- Logs all events for retrospective analysis
- Easy to use: just type `check-cls`

---

## 2. Goals

1. **Smart Heartbeat Detection**
   - Wait for first heartbeat before alerting
   - Track last activity timestamp
   - Only alert if heartbeat was seen and then stopped

2. **macOS Notifications**
   - Send native macOS notifications on freeze detection
   - Configurable (can be disabled)

3. **Auto-Kill with Cooldown**
   - Optional auto-kill of CLS/Cursor processes
   - Cooldown period to prevent rapid kills
   - Configurable kill command

4. **Logging**
   - Persistent log file for all events
   - Timestamped entries
   - Configurable (can be disabled)

5. **Easy Entrypoint**
   - Simple `check-cls` command
   - Thin wrapper for future extensibility

---

## 3. Scope

### ✅ Included
- `tools/watch_cls_alive.zsh` - Main watcher script
- `tools/check-cls` - Entrypoint wrapper
- Heartbeat file: `$HOME/02luka/state/cls_last_activity`
- Log file: `$HOME/02luka/logs/cls_watcher.log`
- Environment variable configuration
- macOS notification support
- Auto-kill with cooldown

### ❌ Excluded
- CLS heartbeat generation (separate task - CLS must write heartbeat)
- LaunchAgent setup (can be added later)
- Web dashboard (out of scope)

---

## 4. Requirements

### 4.1 Functional Requirements

1. **Heartbeat Detection**
   - Read timestamp from `$HOME/02luka/state/cls_last_activity`
   - Calculate time since last heartbeat
   - Only alert if heartbeat was previously seen

2. **Configuration (via env vars)**
   - `CHECK_INTERVAL` - Check frequency (default: 5s)
   - `TIMEOUT` - Freeze threshold (default: 15s)
   - `ENABLE_NOTIFY` - macOS notifications (default: 1)
   - `ENABLE_AUTO_KILL` - Auto-kill enabled (default: 0)
   - `ENABLE_LOG` - Logging enabled (default: 1)
   - `CLS_KILL_CMD` - Kill command (default: empty)
   - `KILL_COOLDOWN` - Seconds between kills (default: 60s)

3. **macOS Notifications**
   - Use `osascript` for native notifications
   - Show freeze alert with title/subtitle
   - Configurable on/off

4. **Auto-Kill**
   - Execute `CLS_KILL_CMD` when freeze detected
   - Enforce cooldown period
   - Log kill attempts

5. **Logging**
   - Write to `$HOME/02luka/logs/cls_watcher.log`
   - Timestamp all entries
   - Log: start, heartbeat, freeze, kill attempts

### 4.2 Non-Functional Requirements

- **Performance:** Minimal CPU usage (sleep between checks)
- **Reliability:** Handle missing files gracefully
- **Usability:** Simple command interface
- **Configurability:** All behavior via env vars

---

## 5. Success Criteria

1. ✅ Watcher waits for heartbeat before alerting
2. ✅ macOS notifications work on freeze
3. ✅ Auto-kill respects cooldown
4. ✅ All events logged with timestamps
5. ✅ `check-cls` command works
6. ✅ Configurable via environment variables

---

## 6. Clarifying Questions

**Q1:** Should watcher run continuously or one-shot?  
**A:** Continuous (infinite loop with sleep) - user can Ctrl+C to stop

**Q2:** What happens if state directory doesn't exist?  
**A:** Create it automatically (mkdir -p)

**Q3:** Should we add LaunchAgent setup in this PR?  
**A:** No - keep it simple, can add later

**Q4:** What's the default kill command?  
**A:** Empty by default - user must set `CLS_KILL_CMD` explicitly

---

## 7. Assumptions

- CLS will write heartbeat to `$HOME/02luka/state/cls_last_activity`
- macOS environment (for notifications)
- zsh shell available
- User can configure env vars as needed

---

## 8. Dependencies

- **CLS heartbeat:** CLS must write timestamp to state file
- **macOS:** For notifications (osascript)
- **zsh:** Shell interpreter

---

## 9. Risks

- **Low Risk:** Tool-only change, no system impact
- **Mitigation:** All features are optional/configurable
- **Rollback:** Simple - just don't use the tool

---

**Status:** ✅ SPEC Complete  
**Next:** Create PLAN.md
