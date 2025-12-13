# Phase 2C-Mini: Orchestrator Services - Quick Checklist

**Target:** 3 Critical Orchestrator Services (Exit 2)  
**Priority:** HIGH (affects delegation, WO execution, watchdog)  
**Date:** 2025-12-07

---

## Services

1. `com.02luka.mary-coo` - Mary COO (delegation orchestrator)
2. `com.02luka.delegation-watchdog` - Delegation watchdog (monitors stuck tasks)
3. `com.02luka.clc-executor` - CLC executor (WO execution)

---

## Quick Checklist (Per Service)

### Pre-Flight
- [ ] Check current status: `launchctl list | grep "<service>"`
- [ ] Check plist exists: `ls ~/Library/LaunchAgents/<service>.plist`
- [ ] Check log exists: `ls ~/02luka/logs/<service>*.log`

### Investigation
- [ ] Read plist: `plutil -p ~/Library/LaunchAgents/<service>.plist`
- [ ] Extract script path from `ProgramArguments`
- [ ] Check script exists: `test -f <script_path>`
- [ ] Check script executable: `test -x <script_path>`
- [ ] Check recent log errors: `tail -20 ~/02luka/logs/<service>*.log`

### Decision (Q1-Q3)
- [ ] Q1: Still needed? (Y/N/DEFER)
- [ ] Q2: If yes: Path/script correct? (Y/N)
- [ ] Q3: If no: REMOVE or ARCHIVE?

### Action
- [ ] FIX: Update paths, make executable, reload
- [ ] REMOVE: Bootout + archive plist
- [ ] ARCHIVE: Bootout + archive plist
- [ ] DEFER: Document reason

### Verification
- [ ] Reload: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<service>.plist`
- [ ] Check exit code: `launchctl list | grep "<service>"`
- [ ] Check log for errors: `tail -10 ~/02luka/logs/<service>*.log`

### Update Status
- [ ] Update `launchagent_repair_PHASE2_STATUS.md`
- [ ] Commit: `git add g/reports/system/launchagent_repair_PHASE2_STATUS.md && git commit -m "fix(system): Phase 2C-mini - <service> <decision>"`

---

## Stop Rules

- **One-by-one**: Process 1 service completely before starting next
- **If stuck**: Check logs first, then decide FIX/DEFER/REMOVE
- **If unsure**: DEFER and document reason

---

## Expected Outcomes

- **FIXED**: Service exits 0, logs show no errors
- **REMOVED**: Service booted out, plist archived
- **ARCHIVED**: Service booted out, plist archived (for safety)
- **DEFERRED**: Documented reason, marked in STATUS.md

---

**Reference:** `launchagent_repair_PHASE2_EXAMPLE.md` (health_monitor walkthrough)
