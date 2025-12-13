# LaunchAgent Legacy Analysis & Cleanup Report
**Date:** 2025-12-07  
**Reference:** `cleanup_summary_20251104.md`  
**Status:** 🔍 ANALYSIS COMPLETE

---

## Executive Summary

**Total LaunchAgents:** 73 (was 82, after Phase 1 cleanup)  
**Healthy (Exit 0):** 26 ✅  
**Ghost Services (Exit 127):** 0 ✅ **CLEANED** (was 9)  
**Configuration Errors (Exit 78):** 38 ⚠️ **INVESTIGATE** (Phase 2)  
**Runtime Errors (Exit 1/2/254):** 9 ⚠️ **INVESTIGATE** (Phase 2)  
**Duplicates:** 0 ✅ **RESOLVED** (was 1)

---

## 1. Ghost Services (Exit 127) - **REMOVE IMMEDIATELY**

These services have missing executables or broken paths. They were supposed to be cleaned up in Nov 2024 but 9 new ones appeared.

### Services to Remove:
```
com.02luka.build-latest-status
com.02luka.clc.local
com.02luka.followup_tracker
com.02luka.guard-health.daily
com.02luka.json_wo_processor
com.02luka.mcp.health
com.02luka.notify.worker
com.02luka.sync.gdrive.4h
com.02luka.wo_executor
```

### Removal Command:
```bash
for service in \
  com.02luka.build-latest-status \
  com.02luka.clc.local \
  com.02luka.followup_tracker \
  com.02luka.guard-health.daily \
  com.02luka.json_wo_processor \
  com.02luka.mcp.health \
  com.02luka.notify.worker \
  com.02luka.sync.gdrive.4h \
  com.02luka.wo_executor; do
  launchctl bootout gui/$(id -u)/$service 2>/dev/null || true
done
```

### Impact:
- ✅ Cleaner system monitoring
- ✅ No functional impact (already broken)
- ✅ Matches Nov 2024 cleanup pattern

---

## 2. Duplicate Services - **RESOLVE**

### Issue: Auto-Commit Duplicate
- **Old:** `com.02luka.auto.commit` → uses `auto_commit_work.zsh` (legacy)
- **New:** `com.02luka.auto-commit` → uses `auto_commit.zsh` (upgraded)

### Status:
- ✅ New service loaded and working (exit 0)
- ⚠️ Old service still exists in `~/Library/LaunchAgents/`
- ⚠️ Old service NOT loaded (not in launchctl list)

### Action:
```bash
# Remove old plist (already unloaded)
rm ~/Library/LaunchAgents/com.02luka.auto.commit.plist
```

---

## 3. Configuration Errors (Exit 78) - **INVESTIGATE**

38 services with configuration errors. These need individual investigation.

### High Priority (Core Services):
```
com.02luka.health_monitor          # System health
com.02luka.health_server           # Health API
com.02luka.hub-autoindex           # Hub indexing
com.02luka.mls.ledger.monitor      # MLS monitoring
com.02luka.memory.bridge           # Memory bridge
com.02luka.memory.hub              # Memory hub
com.02luka.rag.autosync            # RAG sync
```

### Medium Priority (Feature Services):
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

### Common Causes:
- Missing script files
- Incorrect paths (old `/Users/icmini/LocalProjects/02luka_local_g/` references)
- Missing dependencies
- Invalid plist syntax

### Investigation Command:
```bash
# Check a specific service
launchctl print gui/$(id -u)/com.02luka.health_monitor | grep -A 5 "program"
```

---

## 4. Runtime Errors (Exit 1/2/254) - **INVESTIGATE**

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

### Action:
- Check logs: `~/02luka/logs/<service>.log`
- Verify scripts exist and are executable
- Check dependencies

---

## 5. Healthy Services (Exit 0) - **KEEP**

26 services running correctly:

```
com.02luka.adaptive.collector.daily
com.02luka.adaptive.proposal.gen
com.02luka.auto-commit              # ✅ New upgraded version
com.02luka.clc-bridge
com.02luka.cloudflared.dashboard
com.02luka.cls.wo.cleanup
com.02luka.dashboard.server
com.02luka.expense.autodeploy
com.02luka.followup.generator
com.02luka.gh-monitor
com.02luka.gmx_cli
com.02luka.governance.weekly
com.02luka.localtruth
com.02luka.mary-dispatch
com.02luka.mary-gateway-v3
com.02luka.mcp.fs
com.02luka.mcp.puppeteer
com.02luka.memory.digest.daily
com.02luka.mls.cursor.watcher
com.02luka.mls_watcher
com.02luka.n8n.server
com.02luka.ram-monitor
com.02luka.redis_chain_status
com.02luka.rnd.daily_digest
com.02luka.shell-watcher
com.02luka.telegram-bridge
```

---

## 6. Comparison with Nov 2024 Cleanup

### Nov 2024 (Before):
- Ghost services (127): 14
- After cleanup: 0

### Dec 2025 (Before Phase 1):
- Ghost services (127): 9 ⚠️ **NEW GHOSTS APPEARED**
- Configuration errors (78): 38 (was 26 in Nov 2024)
- Healthy services: 26 (was 14 in Nov 2024)

### Dec 2025 (After Phase 1 - Current):
- Ghost services (127): 0 ✅ **CLEANED** (Phase 1 complete)
- Configuration errors (78): 38 ⏳ **PLANNED** (Phase 2)
- Healthy services: 26 ✅ (stable)
- Total services: 73 (was 82, 9 removed)

### Analysis:
- ✅ Healthy services increased (14 → 26) - good
- ✅ Ghost services cleaned (9 → 0) - Phase 1 complete
- ⏳ Config errors remain (38) - Phase 2 planned
- 📋 Phase 2 repair plan created: `launchagent_repair_PLAN_v01.md`

---

## 7. Recommended Actions

### Immediate (High Priority):
1. **Remove 9 ghost services** (exit 127)
   - Use removal command above
   - Verify: `launchctl list | grep "com.02luka" | awk '$2 == "127"`

2. **Remove duplicate auto.commit plist**
   - `rm ~/Library/LaunchAgents/com.02luka.auto.commit.plist`

### ⏳ Phase 2: PLANNED (Not yet implemented)
3. **Investigate high-priority config errors** (exit 78)
   - Plan: `g/reports/system/launchagent_repair_PLAN_v01.md`
   - Start with: health_monitor, health_server, hub-autoindex
   - Check for old path references
   - Fix or remove broken services
   - Estimated: 2-3 hours

4. **Investigate runtime errors** (exit 1/2/254)
   - Check logs for each service
   - Fix or disable if obsolete
   - See Phase 2 plan for details

### Long Term (Low Priority):
5. **Review all exit 78 services**
   - Create inventory of which are still needed
   - Fix paths or remove obsolete services
   - Document active service list

---

## 8. Verification Commands

### Check Ghost Services (should be 0 after cleanup):
```bash
launchctl list | grep "com.02luka" | awk '$2 == "127" | wc -l'
```

### Check Healthy Services:
```bash
launchctl list | grep "com.02luka" | awk '$2 == "0" | wc -l'
```

### List All Services by Status:
```bash
launchctl list | grep "com.02luka" | sort -k2 -n
```

---

## 9. Files to Check

### Plist Locations:
- Active: `~/Library/LaunchAgents/com.02luka.*.plist`
- Source: `~/02luka/Library/LaunchAgents/com.02luka.*.plist`
- Quarantine (Nov 2024): `~/02luka/_plists_quarantine_20251104_000748/`

### Log Locations:
- `~/02luka/logs/<service>.log`
- `~/02luka/logs/<service>.stdout.log`
- `~/02luka/logs/<service>.stderr.log`

---

## 10. Summary Statistics

| Category | Count | Action |
|----------|-------|--------|
| Healthy (Exit 0) | 26 | ✅ Keep |
| Ghost (Exit 127) | 9 | ❌ Remove |
| Config Error (Exit 78) | 38 | ⚠️ Investigate |
| Runtime Error (Exit 1/2/254) | 9 | ⚠️ Investigate |
| **Total** | **82** | |

---

## Next Steps

1. ✅ Run ghost service removal
2. ✅ Remove duplicate auto.commit plist
3. ⏳ Create investigation plan for exit 78 services
4. ⏳ Document which services are still needed
5. ⏳ Update system documentation with active service list

---

**Report Generated:** 2025-12-07  
**Next Review:** After cleanup actions completed
