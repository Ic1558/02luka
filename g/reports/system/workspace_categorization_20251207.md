# 02luka Workspace Categorization

**Analysis Date:** 2025-12-07  
**Total LaunchAgents:** 72  
**Active (Running):** 6  
**Total Plist Files:** 32

---

## 🟢 ACTIVE - Production & Daily Use

### LaunchAgents (6 Running)
| Service | PID | Status |
|---------|-----|--------|
| `com.02luka.cloudflared.dashboard` | 2370 | ✅ Running |
| `com.02luka.dashboard.server` | 2354 | ✅ Running |
| `com.02luka.gh-monitor` | 2411 | ✅ Running |
| `com.02luka.mary-gateway-v3` | 78964 | ✅ Running |
| `com.02luka.mls_watcher` | 2360 | ✅ Running |
| `com.02luka.n8n.server` | 2405 | ✅ Running |

### Features
- **GitDrop Phase 1** - Auto-backup before checkout ✅
- **MLS System** - Knowledge ledger ✅
- **Telemetry Aggregation** - Every 30min ✅
- **Liam Audit Logger** - Logging decisions ✅
- **RAM Monitor** - Running ✅
- **save-now / seal-now** - Aliases working ✅

### Tools (Daily Use)
- `tools/session_save.zsh` - Session saves
- `tools/gitdrop.py` - Workspace safety
- `tools/mls_add.zsh` - MLS entries
- `g/core/lib/audit_logger.py` - Audit logging

---

## 🟡 NICE TO HAVE - Enhancement Features

### LaunchAgents (Loaded but Idle)
- `com.02luka.auto-commit` - Hourly auto-commit
- `com.02luka.memory.digest.daily` - Daily memory summaries
- `com.02luka.governance.weekly` - Weekly governance checks
- `com.02luka.nas_backup_daily` - Daily backups
- `com.02luka.doctor` - System health checks

### Features
- GitDrop Phase 2/3 - Deferred features
- Multi-Agent Coordination Layer 4/5 - Aggregation, adapters
- Telemetry hourly aggregation - Currently 30min

### Tools
- `tools/ram_cleanup_fast.zsh` (ram-cc) - Quick cleanup
- `tools/clear_mem_optimized.zsh` (ram-c) - Deep cleanup
- `tools/telemetry_summary.py` - Ad-hoc queries

---

## 🔵 UPGRADE - Needs Improvement

### LaunchAgents (Exit Code Issues from cleanup report)
- **26 services with exit 78** - Configuration errors
  - Non-critical but need individual review
  - Can function without them

### Features Needing Update
- **Telemetry SPEC v01** - Outdated (says 30min, now consensus is 60min/daily)
- **Session_save.zsh** - Could benefit from Multi-Agent Phase 1A
  - Agent context detection
  - Schema versioning
  - Consistent metadata

### Documentation
- Multiple old README files in root
- Conflict resolution docs (may be outdated)

---

## 🔴 LEGACY - Deprecated / Historical

### Ghost LaunchAgents (Already Removed)
```
com.02luka.inbox_daemon          (Exit 127 - Removed)
com.02luka.system_runner.v5      (Exit 127 - Removed)
com.02luka.nightly.selftest      (Exit 127 - Removed)
com.02luka.redis_bridge          (Exit 127 - Removed)
... (14 total removed per cleanup_summary_20251104.md)
```

### Old Scripts / Files
- `WO-*.zsh` files in root - Old Work Order scripts
- `*.patch` files in root - Old patches
- `_archive/` directory - Archived components
- `_implementation_backups/` - Old backups

### Documentation
- `PHASE_21_COMPLETE.md`
- `TOUCHLESS_DEPLOYMENT_COMPLETE.md`
- `PR_CONFLICTS_SUMMARY.md`
- Multiple `CONFLICT_*.md` files

### LaunchAgents (Likely Obsolete)
Services loaded but idle, no clear purpose:
- `com.02luka.rnd.*` - Old R&D agents
- `com.02luka.phase15.quickhealth` - Phase 15 specific
- `com.02luka.gci.topic.reports` - Old reports

---

## 📊 Summary Table

| Category | LaunchAgents | Features | Tools | Docs |
|----------|--------------|----------|-------|------|
| 🟢 **ACTIVE** | 6 running | 6 key systems | 5 daily | Current |
| 🟡 **NICE TO HAVE** | ~15 idle | 3 enhancements | 3 utils | Future plans |
| 🔵 **UPGRADE** | 26 (exit 78) | 2 systems | 1 core script | Some outdated |
| 🔴 **LEGACY** | 14 removed + ~25 obsolete | Old R&D | Old patches | Archive docs |

---

## 💡 Recommendations

### Immediate (Can Do Now)
1. ✅ Archive old WO-*.zsh and *.patch files in root
2. ✅ Review 26 LaunchAgents with exit 78
3. ✅ Clean up root-level documentation (move to `docs/archive/`)

### Short Term (Next 2 Weeks)
1. ⏳ Implement Multi-Agent Phase 1A (agent context + gateway)
2. ⏳ Update telemetry SPEC to v02 (align with consensus)
3. ⏳ Unload clearly obsolete LaunchAgents (rnd.*, phase15.*)

### Long Term (Future)
1. ⏸️ Evaluate GitDrop Phase 2 after 2-week monitoring
2. ⏸️ Consolidate documentation structure
3. ⏸️ Archive _implementation_backups/

---

## ✅ Already Protected by GitDrop

All current work is now protected:
- 6 snapshots in `_gitdrop/`
- Pre-checkout hook active
- No more data loss risk

---

**Analysis Complete: 2025-12-07**
