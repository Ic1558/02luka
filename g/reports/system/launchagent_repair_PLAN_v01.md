# LaunchAgent Repair Plan - Phase 2
**Date:** 2025-12-07  
**Status:** 📋 **PLAN CREATED** (Not yet implemented)  
**Reference:** `launchagent_legacy_analysis_20251207.md`

---

## Overview

This plan addresses LaunchAgents with configuration errors (exit 78) and runtime errors (exit 1/2/254) identified in the legacy analysis. Phase 1 (ghost services cleanup) must be completed first.

---

## Current Status (After Phase 1)

**Ghost Services (Exit 127):** ✅ **CLEANED** (9 removed)  
**Duplicate Plist:** ✅ **REMOVED** (auto.commit)  
**Config Errors (Exit 78):** ⏳ **38 services** - Needs repair  
**Runtime Errors (Exit 1/2/254):** ⏳ **9 services** - Needs investigation

---

## Phase 2: Repair Strategy

### Approach: Batch Processing by Priority

1. **Core Services First** (High Priority)
   - System health, monitoring, bridges
   - Fix or remove if obsolete

2. **Feature Services** (Medium Priority)
   - Optional features, integrations
   - Fix if needed, remove if obsolete

3. **Obsolete Services** (Low Priority)
   - Legacy features, deprecated systems
   - Remove if no longer needed

---

## Group 1: Core Services (Exit 78) - **HIGH PRIORITY**

### Services:
```
com.02luka.health_monitor          # System health monitoring
com.02luka.health_server           # Health API server
com.02luka.hub-autoindex           # Hub indexing
com.02luka.mls.ledger.monitor      # MLS ledger monitoring
com.02luka.memory.bridge           # Memory bridge
com.02luka.memory.hub              # Memory hub
com.02luka.rag.autosync            # RAG auto-sync
```

### Investigation Steps:
1. Check plist path references
2. Verify script files exist
3. Check for old path references (`/Users/icmini/LocalProjects/02luka_local_g/`)
4. Verify dependencies
5. Test script execution manually

### Common Fixes:
- Update paths from old location to `/Users/icmini/02luka/`
- Fix missing script references
- Update log paths
- Fix plist syntax errors

### Success Criteria:
- All core services exit code 0 or removed if obsolete
- System health monitoring functional
- Memory bridge operational

---

## Group 2: Feature Services (Exit 78) - **MEDIUM PRIORITY**

### Services:
```
com.02luka.antigravity.liam_worker
com.02luka.backup.gdrive
com.02luka.ci-coordinator
com.02luka.ci-watcher
com.02luka.claude.metrics.collector
com.02luka.clc-worker
com.02luka.clc_local
com.02luka.clc_wo_bridge
com.02luka.dashboard.daily
com.02luka.gg.nlp-bridge
com.02luka.gg_session_worker
com.02luka.health.dashboard
com.02luka.kim.bot
com.02luka.lac-activity-daily
com.02luka.mary-bridge
com.02luka.mary.metrics.daily
com.02luka.memory.metrics
com.02luka.nas_backup_daily
com.02luka.nlp-dispatcher
com.02luka.opal-api
com.02luka.opal-healthv2
com.02luka.phase15.quickhealth
com.02luka.pr_score_rnd_dispatcher
com.02luka.rag.api
com.02luka.rag.probe
com.02luka.rnd.autopilot
com.02luka.rnd.consumer
com.02luka.rnd.gate
com.02luka.shell-executor
com.02luka.sot_dashboard_sync
```

### Investigation Steps:
1. Determine if service is still needed
2. Check if feature is active/used
3. Fix paths or remove if obsolete
4. Document decision (fix/remove/defer)

### Decision Matrix:
- **Fix:** Service is needed and fixable
- **Remove:** Service is obsolete or replaced
- **Defer:** Service is optional, can wait

---

## Group 3: Runtime Errors (Exit 1/2/254) - **INVESTIGATE INDIVIDUALLY**

### Exit Code 1 (Minor Errors):
```
com.02luka.bridge.knowledge.sync
com.02luka.gmx-clc-orchestrator
com.02luka.lac-manager
com.02luka.mls.status.update
com.02luka.wo_executor.codex
```

### Exit Code 2 (Errors):
```
com.02luka.clc-executor
com.02luka.delegation-watchdog
com.02luka.doctor
com.02luka.mary-coo
```

### Exit Code 254 (Fatal Error):
```
com.02luka.mcp.memory
```

### Investigation Steps:
1. Check service logs: `~/02luka/logs/<service>.log`
2. Verify script exists and is executable
3. Check dependencies and environment
4. Test manual execution
5. Review recent changes that might have broken it

### Action:
- Fix if critical service
- Remove if obsolete
- Document if intermittent/non-critical

---

## Implementation Plan

### Phase 2A: Core Services Repair (Estimated: 30-45 min)

**Tasks:**
1. Create investigation script for each core service
2. Check plist files for path issues
3. Fix paths or remove obsolete services
4. Test and verify exit codes
5. Document fixes

**Script Template:**
```bash
#!/usr/bin/env zsh
# Check and fix a specific LaunchAgent
SERVICE="com.02luka.health_monitor"
PLIST="$HOME/Library/LaunchAgents/${SERVICE}.plist"

# Check if plist exists
if [[ ! -f "$PLIST" ]]; then
  echo "❌ Plist not found: $PLIST"
  exit 1
fi

# Check for old path references
if grep -q "/Users/icmini/LocalProjects/02luka_local_g/" "$PLIST"; then
  echo "⚠️  Found old path reference"
  # Fix path...
fi

# Check if script exists
SCRIPT_PATH=$(plutil -extract ProgramArguments.1 raw "$PLIST" 2>/dev/null)
if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "❌ Script not found: $SCRIPT_PATH"
fi
```

### Phase 2B: Feature Services Review (Estimated: 60-90 min)

**Tasks:**
1. Create inventory of which features are active
2. Batch check plist files for common issues
3. Fix or remove based on usage
4. Document decisions

**Decision Criteria:**
- Last used date (check logs)
- Feature status (active/deprecated)
- Dependencies (still available?)
- Replacement service exists?

### Phase 2C: Runtime Error Investigation (Estimated: 30-45 min)

**Tasks:**
1. Check logs for each service
2. Identify root cause
3. Fix or remove
4. Document resolution

---

## Tools Needed

### 1. Investigation Script
**File:** `tools/launchagent_investigate.zsh`
**Purpose:** Check a single LaunchAgent for common issues

### 2. Batch Path Fixer
**File:** `tools/launchagent_fix_paths.zsh`
**Purpose:** Fix old path references in plist files

### 3. Service Status Checker
**File:** `tools/launchagent_status_report.zsh`
**Purpose:** Generate status report for all services

---

## Success Metrics

### Phase 2A (Core Services):
- ✅ All 7 core services exit code 0 or removed
- ✅ System health monitoring functional
- ✅ Memory bridge operational

### Phase 2B (Feature Services):
- ✅ All feature services either fixed or removed
- ✅ No obsolete services remaining
- ✅ Active features documented

### Phase 2C (Runtime Errors):
- ✅ All runtime errors resolved or services removed
- ✅ Logs reviewed and documented
- ✅ Critical services verified working

---

## Risk Assessment

### Low Risk:
- Removing obsolete services (already broken)
- Fixing path references (mechanical fix)

### Medium Risk:
- Fixing core services (may affect system monitoring)
- Removing feature services (may break integrations)

### Mitigation:
- Test each fix individually
- Keep backups of plist files
- Document all changes
- Verify system health after changes

---

## Rollback Plan

If issues occur:
1. Restore plist files from git history
2. Reload LaunchAgents: `launchctl bootstrap gui/$(id -u) <plist>`
3. Check system health: `~/02luka/tools/system_health_check.zsh`

---

## Next Steps

1. ✅ **Phase 1 Complete:** Ghost services cleaned
2. ⏳ **Phase 2A:** Start with core services (health_monitor, health_server)
3. ⏳ **Phase 2B:** Review feature services
4. ⏳ **Phase 2C:** Investigate runtime errors

---

## Notes

- **Timing:** Phase 2 should be done when system is stable
- **Testing:** Test each fix before moving to next
- **Documentation:** Update analysis report as fixes are made
- **Monitoring:** Watch system health after each batch of fixes

---

**Plan Created:** 2025-12-07  
**Status:** Ready for implementation (after Phase 1 verification)  
**Estimated Total Time:** 2-3 hours for all phases
