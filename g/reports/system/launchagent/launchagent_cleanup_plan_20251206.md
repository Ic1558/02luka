# LaunchAgent Audit & Cleanup Plan

**Total Agents:** 78  
**Running:** 6  
**Failed/Dormant:** 72  
**Date:** 2025-12-06

---

## 📊 Status Summary

### Running (6 agents)
```
✅ com.02luka.clc_local              (PID: 3409)
✅ com.02luka.cloudflared.dashboard  (PID: 88663)
✅ com.02luka.dashboard.server       (PID: 3455)
✅ com.02luka.gh-monitor             (PID: 3501)
✅ com.02luka.mcp.fs                 (PID: 80656)
✅ com.02luka.mls_watcher            (PID: 3461)
✅ com.02luka.n8n.server             (PID: 3495)
✅ com.02luka.opal-api               (PID: 3480)
✅ com.02luka.shell-executor         (PID: 80708)
```

### Failed/Dormant (69 agents)
Exit codes: 78 (EX_CONFIG), 127 (command not found), 1, 2, 64, 254

---

## 🗂️ Categorized by Function

### **1. CLC/LAC System (9 agents)**

**Active:**
- ✅ `clc_local` (running)

**Duplicates/Failed:**
- ❌ `clc.local` (duplicate of clc_local)
- ❌ `clc-bridge`
- ❌ `clc-executor`
- ❌ `clc-worker`
- ❌ `clc_wo_bridge`
- ❌ `lac-manager`
- ❌ `lac-activity-daily`

**Issues:**
- Multiple CLC agents with overlapping functions
- `clc.local` vs `clc_local` - naming inconsistency/duplicate

**Recommendation:**
- ✅ Keep: `clc_local`
- ❌ Remove: `clc.local`, `clc-bridge`, `clc-executor`, `clc-worker`

---

### **2. Memory/MLS System (9 agents)**

**Active:**
- ✅ `mls_watcher`

**Failed:**
- ❌ `memory.bridge` (exit 78)
- ❌ `memory.digest.daily` (exit 78)
- ❌ `memory.hub` (exit 78)
- ❌ `memory.metrics` (exit 78)
- ❌ `mls.cursor.watcher`
- ❌ `mls.ledger.monitor`
- ❌ `mls.status.update`

**Issues:**
- 4 memory.* agents all failing with same error
- Overlap with MCP memory system

**Recommendation:**
- ✅ Keep: `mls_watcher`
- ❌ Remove: All failed memory.* agents (consolidate to MCP)

---

### **3. MCP System (4 agents)**

**Active:**
- ✅ `mcp.fs`

**Failed:**
- ❌ `mcp.health` (exit 127)
- ❌ `mcp.memory` (exit 254)
- ❌ `mcp.puppeteer`

**Recommendation:**
- ✅ Keep: `mcp.fs`
- ⚠️ Fix or remove others

---

### **4. Mary/Bridge System (5 agents)**

**All Failed:**
- ❌ `mary-bridge` (exit 1)
- ❌ `mary-coo`
- ❌ `mary-dispatch`
- ❌ `mary.metrics.daily` (exit 78)
- ❌ `bridge.knowledge.sync` (exit 1)

**Issues:**
- Entire Mary system appears non-functional

**Recommendation:**
- ❌ Remove all if Mary system deprecated
- ⚠️ Or fix if still needed

---

### **5. Dashboard/Health (7 agents)**

**Active:**
- ✅ `dashboard.server`

**Failed:**
- ❌ `dashboard.daily` (exit 78)
- ❌ `health.dashboard`
- ❌ `health.server`
- ❌ `health_monitor` (exit 78)
- ❌ `health_server`
- ❌ `phase15.quickhealth`

**Duplicates:**
- `health.dashboard` vs `health.server` vs `health_server` vs `health_monitor`

**Recommendation:**
- ✅ Keep: `dashboard.server`
- ❌ Remove: All health.* duplicates
- ❌ Remove: `phase15.quickhealth` (legacy)

---

### **6. RND System (5 agents)**

**All Failed (exit 78):**
- ❌ `rnd.autopilot`
- ❌ `rnd.consumer`
- ❌ `rnd.daily_digest`
- ❌ `rnd.gate`
- ❌ `pr_score_rnd_dispatcher`

**Recommendation:**
- ❌ Remove all (appears abandoned)

---

### **7. RAG System (3 agents)**

**All Failed (exit 78):**
- ❌ `rag.api`
- ❌ `rag.autosync`
- ❌ `rag.probe`

**Recommendation:**
- ❌ Remove (likely deprecated)

---

### **8. Opal System (3 agents)**

**Active:**
- ✅ `opal-api`

**Failed:**
- ❌ `opal-healthv2` (exit 78)

**Recommendation:**
- ✅ Keep: `opal-api`
- ❌ Remove: `opal-healthv2`

---

### **9. GMX/GG System (4 agents)**

**Failed:**
- ❌ `gmx-clc-orchestrator` (exit 1)
- ❌ `gmx_cli`
- ❌ `gg.nlp-bridge` (exit 78)
- ❌ `gg_session_worker` (exit 78)

**Recommendation:**
- ⚠️ Review: GMX system might still be needed
- Fix or remove GG.* agents

---

### **10. Backup/Sync (5 agents)**

**Failed:**
- ❌ `backup.gdrive` (exit 78)
- ❌ `sync.gdrive.4h` (exit 127)
- ❌ `nas_backup_daily` (exit 78)
- ❌ `sot_dashboard_sync` (exit 78)
- ❌ `auto.commit` (exit 78)

**Recommendation:**
- ⚠️ Critical: Review backup strategy
- Fix or replace with working solution

---

### **11. Monitoring (6 agents)**

**Active:**
- ✅ `gh-monitor`
- ✅ `cloudflared.dashboard`

**Failed:**
- ❌ `ci-coordinator` (exit 78)
- ❌ `ci-watcher` (exit 78)
- ❌ `guard-health.daily` (exit 127)
- ❌ `redis_chain_status`

**Recommendation:**
- ✅ Keep: `gh-monitor`, `cloudflared.dashboard`
- ❌ Remove: Failed CI agents

---

### **12. WO/Execution System (7 agents)**

**Active:**
- ✅ `shell-executor`

**Failed:**
- ❌ `wo_executor` (exit 127)
- ❌ `wo_executor.codex`
- ❌ `json_wo_processor` (exit 127)
- ❌ `followup.generator`
- ❌ `followup_tracker` (exit 127)
- ❌ `delegation-watchdog` (exit 2)

**Issues:**
- Multiple WO executors (duplication)

**Recommendation:**
- ✅ Keep: `shell-executor`
- ❌ Remove: Duplicate executors

---

### **13. Misc/Utilities (11 agents)**

**Active:**
- ✅ `n8n.server`

**Failed/Unclear:**
- ❌ `adaptive.collector.daily`
- ❌ `adaptive.proposal.gen`
- ❌ `antigravity.liam_worker` (exit 2)
- ❌ `build-latest-status` (exit 127)
- ❌ `claude.metrics.collector`
- ❌ `cls.wo.cleanup`
- ❌ `doctor`
- ❌ `expense.autodeploy`
- ❌ `governance.weekly`
- ❌ `hub-autoindex`
- ❌ `kim.bot` (exit 78)
- ❌ `localtruth`
- ❌ `nlp-dispatcher`
- ❌ `shell-watcher`
- ❌ `telegram-bridge`
- ❌ `sot.render`

---

## 🔥 Cleanup Plan

### **Phase 1: Remove Obvious Duplicates (18 agents)**

```bash
# CLC duplicates
launchctl unload ~/Library/LaunchAgents/com.02luka.clc.local.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.clc-bridge.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.clc-executor.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.clc-worker.plist

# Health duplicates
launchctl unload ~/Library/LaunchAgents/com.02luka.health.dashboard.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.health.server.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.health_server.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.health_monitor.plist

# Memory duplicates
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.bridge.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.digest.daily.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.hub.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.metrics.plist

# WO duplicates
launchctl unload ~/Library/LaunchAgents/com.02luka.wo_executor.codex.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.json_wo_processor.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.followup_tracker.plist

# Dashboard duplicates
launchctl unload ~/Library/LaunchAgents/com.02luka.dashboard.daily.plist

# MLS duplicates
launchctl unload ~/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.mls.ledger.monitor.plist
```

**RAM Saved:** ~150-200MB

---

### **Phase 2: Remove Deprecated Systems (20 agents)**

**RND System (5):**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.rnd.*.plist
```

**RAG System (3):**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.rag.*.plist
```

**GG System (2):**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.gg.*.plist
```

**Mary System (5):**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.mary*.plist
```

**CI System (2):**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.ci-*.plist
```

**RAM Saved:** ~100-150MB

---

### **Phase 3: Fix Critical Systems**

**Backup (CRITICAL):**
- ⚠️ `backup.gdrive` - Fix or replace
- ⚠️ `nas_backup_daily` - Fix or replace

**GMX (if needed):**
- `gmx-clc-orchestrator` - Debug exit code 1
- `gmx_cli` - Verify functionality

**Liam Worker:**
- `antigravity.liam_worker` - Debug exit code 2

---

## 📈 Expected Results

**Before:**
- 78 agents loaded
- 72 failing
- ~300MB RAM wasted

**After Phase 1+2:**
- ~40 agents loaded
- ~6-10 running
- ~250MB RAM saved

---

## 🎯 Recommended Keepers (9 agents)

```
✅ clc_local
✅ cloudflared.dashboard
✅ dashboard.server
✅ gh-monitor
✅ mcp.fs
✅ mls_watcher
✅ n8n.server
✅ opal-api
✅ shell-executor
```

**Everything else:** Review, fix, or remove

---

## 🛠️ Cleanup Script

**File:** `tools/cleanup_launchagents.zsh`

```zsh
#!/usr/bin/env zsh
# LaunchAgent Cleanup Script

echo "🧹 LaunchAgent Cleanup"
echo "===================="
echo ""

# Backup first
BACKUP_DIR=~/02luka/backups/launchagents_$(date +%Y%m%d)
mkdir -p "$BACKUP_DIR"
cp ~/Library/LaunchAgents/com.02luka.*.plist "$BACKUP_DIR/"
echo "✅ Backed up to: $BACKUP_DIR"
echo ""

# Phase 1: Duplicates
echo "Phase 1: Removing duplicates..."
DUPLICATES=(
  "clc.local" "clc-bridge" "clc-executor" "clc-worker"
  "health.dashboard" "health.server" "health_server" "health_monitor"
  "memory.bridge" "memory.digest.daily" "memory.hub" "memory.metrics"
  "wo_executor.codex" "json_wo_processor" "followup_tracker"
  "dashboard.daily" "mls.cursor.watcher" "mls.ledger.monitor"
)

for agent in "${DUPLICATES[@]}"; do
  launchctl unload ~/Library/LaunchAgents/com.02luka.$agent.plist 2>/dev/null
  echo "  ❌ Removed: $agent"
done

echo ""
echo "✅ Phase 1 complete!"
echo ""
echo "📊 Remaining agents:"
launchctl list | grep 02luka | wc -l
```

---

**Next Steps:**
1. Review this plan
2. Run backup
3. Execute Phase 1 (duplicates)
4. Monitor system
5. Execute Phase 2 (deprecated)
6. Fix critical systems (Phase 3)

---

**Status:** Ready for Boss approval
