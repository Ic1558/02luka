# Feature SPEC: RAM/System Monitoring & Auto-Remediation

**Feature:** Comprehensive RAM and system resource monitoring with 5-layer defensive architecture  
**Date:** 2025-11-17  
**Status:** Draft  
**Priority:** High (Post-Crisis Prevention)

---

## Executive Summary

Build a comprehensive RAM/system monitoring and auto-remediation system to prevent future RAM exhaustion crises like the one experienced on 2025-11-17 (22GB/23.5GB swap saturation, 50+ LaunchAgents in crash loops).

**Goal:** Never exceed 80% swap usage again, with automatic detection, alerting, and remediation.

---

## Problem Statement

### The Crisis (2025-11-17)
- **Swap Usage:** 22GB / 23.5GB (94% saturation) ⚠️
- **Load Average:** 32.39 / 78.52 / 50.06 (CRITICAL)
- **Root Cause:** 50+ LaunchAgents in infinite crash loops (scripts deleted during refactoring)
- **Impact:** System unresponsive, massive CPU/memory waste
- **Recovery Time:** 25 minutes manual intervention

### Root Causes
1. **No real-time monitoring** - No alerts when swap exceeded 75%
2. **No crash loop detection** - Agents restarted infinitely without circuit breaker
3. **No preventive validation** - LaunchAgent plists not validated before deployment
4. **No auto-remediation** - Manual intervention required for crisis
5. **No learning loop** - Crisis not captured for future prevention

---

## Solution: 5-Layer Defensive Architecture

### Layer 1: Real-Time Monitoring (NEW)
**Purpose:** Detect RAM/swap pressure and process anomalies immediately

**Components:**
- `tools/ram_guard.zsh` - Monitor swap/load/memory pressure every 60s
- `tools/process_watchdog.zsh` - Track all processes >500MB, detect leaks
- `tools/agent_health_monitor.zsh` - Detect crash loops, log bloat
- Redis pub/sub: `02luka:alerts:ram` channel for alerts

**Thresholds:**
- Swap >75% = WARNING (alert only)
- Swap >90% = CRITICAL (alert + auto-remediation)
- Load average >10 = WARNING
- Process >2GB = WARNING (potential leak)
- Agent restart >5 in 5min = CRITICAL (crash loop)

**Output:**
- Redis alerts: `{"type": "ram_warning|ram_critical|process_leak|crash_loop", "swap_pct": 85, "timestamp": "..."}`
- Dashboard metrics: Real-time RAM/swap bar
- Logs: `~/02luka/logs/ram_guard.log`

---

### Layer 2: Preventive Measures (HARDENING)
**Purpose:** Prevent issues before they occur

**Components:**
- `tools/validate_launchagents.zsh` - Pre-commit hook validates script paths exist
- `g/docs/AGENT_REGISTRY.md` - Document all 75 agents (purpose, critical/optional)
- Log rotation - Fix 50MB `mls_cursor_watcher.log` bloat
- Smart backup - Add load checks to `backup_to_gdrive.zsh`

**Validation Rules:**
- All LaunchAgent plists must reference existing scripts
- Scripts must be executable
- Paths must be absolute (no `~/` expansion issues)
- ThrottleInterval must be set for KeepAlive agents

**Agent Registry:**
- Purpose: Document what each agent does
- Criticality: Critical / Optional / Legacy
- Dependencies: What scripts/files it needs
- Health checks: How to verify it's working

---

### Layer 3: Auto-Remediation (SELF-HEALING)
**Purpose:** Automatically recover from crises without manual intervention

**Components:**
- `tools/ram_crisis_handler.zsh` - Auto-kill non-critical processes at swap >90%
- Crash loop circuit breaker - Disable agents after 5 restarts in 5min
- Swap emergency flush - Prompt user to close memory-heavy apps

**Safe Kill List:**
- Non-critical processes (identified by user)
- Processes >2GB RSS (potential leaks)
- Crash-looping agents (after circuit breaker)
- **NEVER kill:** Critical services (backup, expense, dashboard)

**Circuit Breaker Logic:**
1. Track agent restart count in last 5 minutes
2. If >5 restarts → disable agent (unload LaunchAgent)
3. Log to MLS with tag `crash_loop_auto_disable`
4. Alert user via notification

---

### Layer 4: Alert/Notification (INTEGRATION)
**Purpose:** Route alerts to appropriate channels

**Components:**
- `tools/alert_router.zsh` - Route Redis alerts to macOS notifications + Telegram
- Dashboard resources panel - Add RAM/swap bar + top consumers
- API endpoint `/api/system/resources` for real-time display

**Alert Channels:**
- **macOS Notifications:** All WARNING/CRITICAL alerts
- **Telegram:** CRITICAL only (if configured)
- **Dashboard:** Real-time metrics panel
- **Redis:** Pub/sub for other services

**Alert Format:**
```json
{
  "type": "ram_warning|ram_critical|process_leak|crash_loop",
  "severity": "warning|critical",
  "message": "Human-readable message",
  "swap_pct": 85,
  "swap_used_gb": 20.5,
  "swap_total_gb": 23.5,
  "load_avg": 8.5,
  "timestamp": "2025-11-17T02:30:00Z",
  "actions_taken": ["alert_sent", "process_killed"]
}
```

---

### Layer 5: Learning/Documentation (MLS)
**Purpose:** Capture incidents and learn from them

**Components:**
- Auto-capture crisis events to MLS with tags (`ram`, `crisis`, `auto-heal`)
- Post-mortem generator - Create incident reports in `g/reports/incidents/`
- Weekly health digest - Track RAM/swap trends over time

**MLS Capture:**
- Type: `failure` or `improvement`
- Tags: `ram`, `crisis`, `auto-heal`, `crash_loop`
- Problem: What happened
- Solution: What was done (auto or manual)
- Prevention: What can prevent this in future

**Incident Reports:**
- Location: `g/reports/incidents/RAM_CRISIS_YYYYMMDD.md`
- Format: Markdown with timeline, root cause, actions taken, lessons learned
- Auto-generated on CRITICAL events

**Weekly Digest:**
- Location: `g/reports/health/weekly_digest_YYYYMMDD.md`
- Content: RAM/swap trends, top consumers, agent health, incidents

---

## Technical Requirements

### Infrastructure Dependencies
- **Redis:** Must be running (Homebrew, 127.0.0.1:6379)
- **macOS Notifications:** `osascript` for native notifications
- **Telegram:** Optional, via existing bridge if configured
- **Dashboard:** Existing `g/apps/dashboard/` structure
- **MLS:** Existing `~/02luka/tools/mls_capture.zsh`

### File Locations
- **Tools:** `~/02luka/tools/`
- **LaunchAgents:** `~/Library/LaunchAgents/`
- **Logs:** `~/02luka/logs/`
- **Reports:** `~/02luka/g/reports/`
- **Incidents:** `~/02luka/g/reports/incidents/`
- **Health:** `~/02luka/g/reports/health/`
- **Docs:** `~/02luka/g/docs/`

### Performance Requirements
- **Monitoring overhead:** <1% CPU, <50MB RAM
- **Alert latency:** <60 seconds from threshold breach
- **Remediation time:** <5 minutes from CRITICAL to recovery
- **Dashboard update:** Real-time (poll every 5s)

### Compatibility
- **macOS:** 15.1.0+ (Darwin 25.1.0+)
- **Shell:** zsh (default on macOS)
- **Dependencies:** `jq`, `redis-cli`, `osascript`, `vm_stat`, `top`

---

## Success Criteria

### Prevention
- ✅ Never exceed 80% swap usage (alert at 75%, remediate at 90%)
- ✅ All LaunchAgent plists validated before deployment
- ✅ Crash loops detected and disabled within 5 minutes

### Detection
- ✅ Alerts within 1 minute of swap >75%
- ✅ Process leaks detected within 5 minutes
- ✅ Crash loops detected within 5 minutes

### Remediation
- ✅ Auto-recovery from crisis in <5 minutes
- ✅ Non-critical processes killed automatically
- ✅ Crash-looping agents disabled automatically

### Learning
- ✅ All incidents captured in MLS with tags
- ✅ Incident reports auto-generated for CRITICAL events
- ✅ Weekly health digest tracks trends

### Visibility
- ✅ Dashboard shows real-time RAM/swap status
- ✅ Top memory consumers displayed
- ✅ Agent health status visible

---

## Non-Goals

- **Not replacing:** Existing `system_health_check.zsh` (complements it)
- **Not monitoring:** Network, disk I/O (focus on RAM only)
- **Not managing:** Application-level memory (OS-level only)
- **Not replacing:** Manual intervention (augments it)

---

## Open Questions

1. **Safe Kill List:** Which processes are safe to kill? (User to provide list)
2. **Telegram Integration:** Use existing bridge or create new?
3. **Dashboard Backend:** Use existing `api_server.py` or create new endpoint?
4. **MLS Format:** Use existing `mls_capture.zsh` or create specialized capture?
5. **Agent Registry:** Auto-generate from LaunchAgents or manual documentation?

---

## Dependencies

### Existing Infrastructure
- ✅ Redis (Homebrew, running)
- ✅ Dashboard (`g/apps/dashboard/`)
- ✅ MLS (`~/02luka/tools/mls_capture.zsh`)
- ✅ LaunchAgents (`~/Library/LaunchAgents/`)
- ✅ System health check (`tools/system_health_check.zsh`)

### New Dependencies
- None (all tools use standard macOS utilities)

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| False positives (killing wrong process) | High | Safe kill list, user approval for critical kills |
| Monitoring overhead | Medium | Lightweight checks, 60s interval |
| Alert fatigue | Medium | Severity-based filtering, quiet hours |
| Dashboard performance | Low | Polling interval, caching |

---

## Future Enhancements

- **Phase 2:** Network and disk I/O monitoring
- **Phase 3:** Predictive alerts (ML-based trend analysis)
- **Phase 4:** Cross-machine monitoring (if multiple machines)
- **Phase 5:** Integration with external monitoring (Grafana, Prometheus)

---

**Status:** Ready for PLAN creation  
**Next Step:** Create detailed implementation PLAN with tasks and test strategy
