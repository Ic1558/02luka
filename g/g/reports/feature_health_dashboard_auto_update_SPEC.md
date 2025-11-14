# Feature Specification: Health Dashboard Auto-Update

**Feature ID:** `health-dashboard-auto-update`  
**Date:** 2025-11-12  
**Status:** Draft → Ready for Planning

---

## Objective

Automatically update `g/reports/health_dashboard.json` at regular intervals without manual intervention, ensuring the health dashboard always reflects current system status.

---

## Problem Statement

Currently, `run/health_dashboard.cjs` must be executed manually to update the health dashboard. This leads to:
- Stale health data when the script isn't run regularly
- Manual dependency for health monitoring systems
- Inconsistent update frequency
- Risk of missing health status changes

---

## Requirements

### Functional Requirements

1. **Automatic Execution**
   - LaunchAgent must execute `run/health_dashboard.cjs` periodically
   - Interval: Every 15-60 minutes (configurable, default: 30 minutes)
   - Must run on system startup (RunAtLoad: true)

2. **Error Handling**
   - Script failures should not crash the LaunchAgent
   - Errors should be logged to stderr log file
   - LaunchAgent should continue scheduling next execution even if script fails

3. **Logging**
   - Standard output: `~/02luka/logs/health_dashboard.out.log`
   - Standard error: `~/02luka/logs/health_dashboard.err.log`
   - Log rotation handled by existing log rotation system

4. **Environment**
   - Must set proper PATH for Node.js execution
   - Must respect `LUKA_SOT` environment variable if set
   - Must use absolute paths for reliability

### Non-Functional Requirements

1. **Performance**
   - Script execution should complete in < 5 seconds
   - No impact on system performance
   - ThrottleInterval: 30 seconds (prevent rapid re-execution)

2. **Reliability**
   - LaunchAgent should survive system reboots
   - Must handle Node.js path variations (Homebrew vs system)
   - Graceful degradation if script is missing

3. **Maintainability**
   - Follow 02luka LaunchAgent naming conventions
   - Use standard plist structure
   - Document in system documentation

---

## Design Decisions

### LaunchAgent Configuration

**Label:** `com.02luka.health.dashboard`

**Schedule Type:** `StartInterval` (periodic execution every N seconds)
- More flexible than `StartCalendarInterval` for regular intervals
- Consistent with other periodic tasks in 02luka system

**Interval:** 30 minutes (1800 seconds)
- Balance between freshness and system load
- Configurable via plist modification if needed

**KeepAlive:** `false`
- One-shot execution per interval
- Script completes and exits, LaunchAgent schedules next run

**RunAtLoad:** `true`
- Generate dashboard immediately on system startup
- Ensures dashboard is available even if system was down

### Command Execution

**Pattern:**
```bash
node "$HOME/02luka/run/health_dashboard.cjs" || true
```

- Use absolute path to script
- `|| true` ensures LaunchAgent doesn't fail if script errors
- Script handles its own error reporting

### Logging Strategy

- Separate stdout/stderr logs for debugging
- Logs stored in `~/02luka/logs/` (standard location)
- Existing log rotation will handle cleanup

---

## Out of Scope

1. **Dashboard Content Changes**
   - This feature only adds automation, doesn't modify dashboard script
   - Health checks and metrics remain unchanged

2. **Alerting Integration**
   - No automatic alerts on health status changes
   - Dashboard updates are passive (consumers check file)

3. **Dashboard UI**
   - No changes to dashboard visualization
   - Only ensures JSON file is updated

4. **Multi-Machine Support**
   - Designed for single-machine deployment
   - No distributed health aggregation

---

## Success Criteria

1. ✅ LaunchAgent created and installed
2. ✅ Health dashboard updates automatically every 30 minutes
3. ✅ Dashboard updates on system startup
4. ✅ Logs capture script execution and errors
5. ✅ No manual intervention required
6. ✅ System documentation updated

---

## Dependencies

- `run/health_dashboard.cjs` - Must exist and be executable
- Node.js - Must be in PATH or absolute path available
- macOS LaunchAgent system - Required for automation
- Log directory - `~/02luka/logs/` must exist or be creatable

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Node.js path not found | High | Use absolute path or ensure PATH includes Node.js |
| Script fails silently | Medium | Log errors to stderr, monitor logs |
| Log files grow unbounded | Low | Existing log rotation handles this |
| LaunchAgent not loaded | Medium | Provide installation/verification script |
| Script execution too slow | Low | Script is lightweight, < 5s expected |

---

## Open Questions

1. **Interval Preference:** 15, 30, or 60 minutes? → **Decision: 30 minutes** (balanced)
2. **Error Notification:** Should failures trigger alerts? → **Out of scope** (passive updates)
3. **Startup Delay:** Should we delay first execution? → **No delay** (RunAtLoad: true)

---

**Specification Status:** ✅ **READY FOR PLANNING**
