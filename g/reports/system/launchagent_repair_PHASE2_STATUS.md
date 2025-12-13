# LaunchAgent Repair - Phase 2 Status
**Date Started:** 2025-12-07  
**Status:** 🔄 **IN PROGRESS** (Phase 2A started)  
**Reference:** `launchagent_repair_PLAN_v01.md`  
**Safe Start Guide:** `launchagent_repair_PHASE2_SAFE_START.md`

---

## Phase 2 Overview

**Total Services to Repair:** 47
- Core Services (Exit 78): 7
- Feature Services (Exit 78): 31
- Runtime Errors (Exit 1/2/254): 9

**Approach:** Batch processing by priority (Core → Feature → Runtime)

---

## Group 1: Core Services (Exit 78) - **HIGH PRIORITY**

| Service | Status | Decision | Notes |
|--------|--------|-----------|--------|
| `com.02luka.health_monitor` | ✅ FIXED | FIX | Updated paths to /Users/icmini/02luka, exit 1 is expected (health check found issues) |
| `com.02luka.health_server` | ✅ REMOVED | REMOVE | Legacy health API server - health_monitor works, no dependencies |
| `com.02luka.hub-autoindex` | ✅ ARCHIVED | ARCHIVE | Legacy hub indexer - not used in current architecture |
| `com.02luka.mls.ledger.monitor` | ✅ FIXED | FIX | Updated paths to /Users/icmini/02luka, exit 0 |
| `com.02luka.memory.bridge` | ✅ REMOVED | REMOVE | Old bridge worker - memory.hub replaces it, not in current architecture |
| `com.02luka.memory.hub` | ✅ FIXED | FIX | Updated paths and python path, exit 0 |
| `com.02luka.rag.autosync` | ✅ ARCHIVED | ARCHIVE | Legacy RAG autosync - script missing, Phase 15 RAG uses manual sync |

### Decision Codes:
- **FIX** - Service needed, fix paths/config
- **REMOVE** - Service obsolete, remove completely
- **ARCHIVE** - Service obsolete, move to archive
- **DEFER** - Service needed but low priority, fix later

### Investigation Checklist (for each service):
- [ ] Q1: Still needed in current architecture? (Y/N/DEFER)
- [ ] Q2: If yes: Path/script exists and config correct? (Y/N)
- [ ] Q3: If no: Remove or archive? (REMOVE/ARCHIVE)
- [ ] Q4: Old path reference found? (Y/N)
- [ ] Q5: Script file exists? (Y/N)
- [ ] Q6: Script executable? (Y/N)
- [ ] Q7: Log directory exists? (Y/N)
- [ ] Q8: Recent errors in log? (Y/N)

---

## Group 2: Feature Services (Exit 78) - **MEDIUM PRIORITY**

| Service | Status | Decision | Tag | Notes |
|--------|--------|-----------|-----|--------|
| `com.02luka.antigravity.liam_worker` | ⏳ PENDING | - | - | Antigravity integration |
| `com.02luka.backup.gdrive` | ⏳ PENDING | - | - | Google Drive backup |
| `com.02luka.ci-coordinator` | ⏳ PENDING | - | - | CI coordination |
| `com.02luka.ci-watcher` | ⏳ PENDING | - | - | CI watching |
| `com.02luka.claude.metrics.collector` | ⏳ PENDING | - | - | Metrics collection |
| `com.02luka.clc-worker` | ⏳ PENDING | - | - | CLC worker |
| `com.02luka.clc_local` | ⏳ PENDING | - | - | CLC local |
| `com.02luka.clc_wo_bridge` | ⏳ PENDING | - | - | CLC WO bridge |
| `com.02luka.dashboard.daily` | ⏳ PENDING | - | - | Daily dashboard |
| `com.02luka.gg.nlp-bridge` | ⏳ PENDING | - | - | NLP bridge |
| `com.02luka.gg_session_worker` | ⏳ PENDING | - | - | Session worker |
| `com.02luka.health.dashboard` | ⏳ PENDING | - | - | Health dashboard |
| `com.02luka.kim.bot` | ⏳ PENDING | - | - | Kim bot |
| `com.02luka.lac-activity-daily` | ⏳ PENDING | - | - | LAC daily activity |
| `com.02luka.mary-bridge` | ⏳ PENDING | - | - | Mary bridge |
| `com.02luka.mary.metrics.daily` | ⏳ PENDING | - | - | Mary daily metrics |
| `com.02luka.memory.metrics` | ⏳ PENDING | - | - | Memory metrics |
| `com.02luka.nas_backup_daily` | ⏳ PENDING | - | - | NAS daily backup |
| `com.02luka.nlp-dispatcher` | ⏳ PENDING | - | - | NLP dispatcher |
| `com.02luka.opal-api` | ⏳ PENDING | - | - | Opal API |
| `com.02luka.opal-healthv2` | ⏳ PENDING | - | - | Opal health v2 |
| `com.02luka.phase15.quickhealth` | ⏳ PENDING | - | - | Quick health |
| `com.02luka.pr_score_rnd_dispatcher` | ⏳ PENDING | - | - | PR score dispatcher |
| `com.02luka.rag.api` | ⏳ PENDING | - | - | RAG API |
| `com.02luka.rag.probe` | ⏳ PENDING | - | - | RAG probe |
| `com.02luka.rnd.autopilot` | ⏳ PENDING | - | - | RND autopilot |
| `com.02luka.rnd.consumer` | ⏳ PENDING | - | - | RND consumer |
| `com.02luka.rnd.gate` | ⏳ PENDING | - | - | RND gate |
| `com.02luka.shell-executor` | ⏳ PENDING | - | - | Shell executor |
| `com.02luka.sot_dashboard_sync` | ⏳ PENDING | - | - | SOT dashboard sync |

### Tag Codes:
- **ACTIVE_FIX** - Used currently, needs fixing
- **FUTURE** - Planned for future use
- **CANDIDATE_REMOVE** - Not in current architecture, candidate for removal

---

## Group 3: Runtime Errors (Exit 1/2/254) - **INVESTIGATE INDIVIDUALLY**

### Exit Code 1 (Minor Errors):
| Service | Status | Decision | Root Cause | Fix Action |
|--------|--------|-----------|-------------|------------|
| `com.02luka.bridge.knowledge.sync` | ⏳ PENDING | - | - | - |
| `com.02luka.gmx-clc-orchestrator` | ⏳ PENDING | - | - | - |
| `com.02luka.lac-manager` | ⏳ PENDING | - | - | - |
| `com.02luka.mls.status.update` | ⏳ PENDING | - | - | - |
| `com.02luka.wo_executor.codex` | ⏳ PENDING | - | - | - |

### Exit Code 2 (Errors) - **Phase 2C-Mini Priority:**
| Service | Status | Decision | Root Cause | Fix Action |
|--------|--------|-----------|-------------|------------|
| `com.02luka.mary-coo` | ✅ FIXED | FIX | Old path: LocalProjects/02luka_local_g → Updated to gateway_v3_router.py | Updated script path to /Users/icmini/02luka/agents/mary_router/gateway_v3_router.py, exit 0 |
| `com.02luka.delegation-watchdog` | ✅ FIXED | FIX | Old path: LocalProjects/02luka_local_g → Updated to hub/delegation_watchdog.mjs | Updated to Node.js script at /Users/icmini/02luka/hub/delegation_watchdog.mjs, node path /opt/homebrew/bin/node, exit 0 |
| `com.02luka.clc-executor` | ✅ FIXED | FIX | Old path: LocalProjects/02luka_local_g → Updated to clc_local.py | Updated to /Users/icmini/02luka/agents/clc_local/clc_local.py --watch-inbox CLC, exit 1 (no work, acceptable) |
| `com.02luka.doctor` | ⏳ PENDING | - | - | - |

### Exit Code 254 (Fatal Error):
| Service | Status | Decision | Root Cause | Fix Action |
|--------|--------|-----------|-------------|------------|
| `com.02luka.mcp.memory` | ⏳ PENDING | - | - | - |

### Investigation Steps:
1. Check log: `~/02luka/logs/<service>.log`
2. Check script exists and executable
3. Check dependencies
4. Test manual execution
5. Identify root cause
6. Decide: FIX / REMOVE / DEFER

---

## Progress Tracking

### Phase 2A: Core Services
- **Started:** 2025-12-07
- **Completed:** ✅ **COMPLETE**
- **Fixed:** 3/7
- **Removed:** 2/7 (health_server, memory.bridge)
- **Archived:** 2/7 (hub-autoindex, rag.autosync)
- **Deferred:** 0/7

### Phase 2B: Feature Services
- **Started:** TBD
- **Completed:** TBD
- **Fixed:** 0/31
- **Removed:** 0/31
- **Deferred:** 0/31

### Phase 2C: Runtime Errors
- **Started:** TBD
- **Completed:** TBD
- **Fixed:** 0/9
- **Removed:** 0/9
- **Deferred:** 0/9

### Phase 2C-Mini: Orchestrator Services (HIGH PRIORITY)
- **Started:** TBD
- **Completed:** TBD
- **Target:** 3 services (mary-coo, delegation-watchdog, clc-executor)
- **Fixed:** 0/3
- **Removed:** 0/3
- **Deferred:** 0/3
- **Reference:** `launchagent_repair_PHASE2C_MINI_QUICK_CHECKLIST.md`

### Overall Progress
- **Total Services:** 47
- **Completed:** 10/47 (21%)
  - Phase 2A: 7/7 (100%)
  - Phase 2C-Mini: 3/3 (100%)
- **In Progress:** 0/47
- **Pending:** 37/47 (79%)

---

## Quick Start Commands

### Investigate Core Services:
```bash
~/02luka/tools/launchagent_investigate_core.zsh
```

### Check Specific Service:
```bash
SERVICE="com.02luka.health_monitor"
launchctl print "gui/$(id -u)/$SERVICE" | grep -A 5 "program"
cat ~/Library/LaunchAgents/${SERVICE}.plist
```

### Check Logs:
```bash
tail -50 ~/02luka/logs/<service>.log
```

---

## Notes

- Update this file as services are investigated and fixed
- Mark status: PENDING → IN_PROGRESS → FIXED/REMOVED/DEFERRED
- Document root causes and fix actions
- Archive removed plists to `~/02luka/_plists_archive_20251207/`

---

**Last Updated:** 2025-12-07  
**Next Review:** Phase 2B (Feature Services) or remaining Phase 2C (Runtime Errors)
