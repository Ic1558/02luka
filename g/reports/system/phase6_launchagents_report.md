# Phase 6: LaunchAgents Report
**Generated:** 2025-12-13  
**Mode:** Report-Only

---

## 📋 LaunchAgents Found in Repository

### 1. Repository Locations

#### `LaunchAgents/` Directory (28 files)
**Location:** `~/02luka/LaunchAgents/`

**Files Found:**
- com.02luka.adaptive.collector.daily.plist
- com.02luka.adaptive.proposal.gen.plist
- com.02luka.clc-bridge.plist
- com.02luka.clc-worker.plist
- com.02luka.clc.local.plist
- com.02luka.cls.wo.cleanup.plist
- com.02luka.followup.generator.plist
- com.02luka.gg.nlp-bridge.plist
- com.02luka.gmx-clc-orchestrator.plist
- com.02luka.governance.weekly.plist
- com.02luka.health_server.plist
- com.02luka.health.dashboard.plist
- com.02luka.hub-autoindex.plist
- com.02luka.kim.bot.plist
- com.02luka.lpe.worker.plist
- com.02luka.mary-bridge.plist
- com.02luka.mary-dispatch.plist
- com.02luka.mls_watcher.plist
- com.02luka.mls.cursor.watcher.plist
- com.02luka.mls.status.update.plist
- com.02luka.nlp-dispatcher.plist
- com.02luka.opal-healthv2.plist
- com.02luka.phase15.quickhealth.plist
- com.02luka.rag.probe.plist
- com.02luka.shell-executor.plist
- com.02luka.shell-watcher.plist
- com.02luka.context-summary.plist.sample
- com.02luka.hub.plist.sample

#### `launchd/` Directory (6 files)
**Location:** `~/02luka/launchd/`

**Files Found:**
- com.02luka.apply_patch_processor.plist
- com.02luka.followup_tracker.plist
- com.02luka.gmx_cli.plist
- com.02luka.json_wo_processor.plist
- com.02luka.wo_executor.plist
- com.02luka.wo_pipeline_guardrail.plist

#### `Library/LaunchAgents/` Directory (3 files)
**Location:** `~/02luka/Library/LaunchAgents/`

**Files Found:**
- com.02luka.auto.commit.plist
- com.02luka.git.auto.commit.ai.plist
- com.02luka.mls.ledger.monitor.plist

#### Other Locations
- `etc/launchagents/` (3 files: pushgateway, prometheus, dashboard)
- `deploy/launchagents/` (3 files: nlp.dispatcher, daily_health, agent_listener)
- `g/launchd/` (1 file: antigravity-ci)
- `g/maintenance/` (1 file: lac.background)

**Total Found in Repository:** ~48 plist files

---

## 🔍 LaunchAgents Referenced in Chat History

### 1. PR-11 Healthcheck ✅
**Expected:** `~/Library/LaunchAgents/com.02luka.pr11.healthcheck.plist`  
**Status:** ⚠️ **NOT FOUND IN REPO** - แต่มีใน comprehensive report ว่า "Exists and loaded"

**Script:** `tools/pr11_healthcheck_auto.zsh` ✅ (exists)

**Note:** ต้องตรวจสอบว่า plist file อยู่ใน `~/Library/LaunchAgents/` หรือไม่

### 2. Performance Collection Daily ✅
**Expected:** `~/Library/LaunchAgents/com.02luka.perf-collect-daily.plist`  
**Status:** ⚠️ **NOT FOUND IN REPO** - แต่มีใน chat history

**Script:** `tools/perf_collect_daily.zsh` ✅ (exists)

**Setup Script:** `tools/setup_perf_monitoring.zsh` (mentioned in chat history)

**Note:** ต้องตรวจสอบว่า plist file อยู่ใน `~/Library/LaunchAgents/` หรือไม่

### 3. Auto Commit ✅
**Expected:** `~/Library/LaunchAgents/com.02luka.auto.commit.plist`  
**Status:** ✅ **FOUND IN REPO** - `Library/LaunchAgents/com.02luka.auto.commit.plist`

**Known Issue:** Comment mismatch (line 24: says 3600s but StartInterval is 1800s)

### 4. Git Auto Commit AI ✅
**Expected:** `~/Library/LaunchAgents/com.02luka.git.auto.commit.ai.plist`  
**Status:** ✅ **FOUND IN REPO** - `Library/LaunchAgents/com.02luka.git.auto.commit.ai.plist`

### 5. MLS Ledger Monitor ✅
**Expected:** `~/Library/LaunchAgents/com.02luka.mls.ledger.monitor.plist`  
**Status:** ✅ **FOUND IN REPO** - `Library/LaunchAgents/com.02luka.mls.ledger.monitor.plist`

### 6. Mary COO (Gateway v3 Router) ✅
**Expected:** `~/Library/LaunchAgents/com.02luka.mary-coo.plist`  
**Status:** ⚠️ **NOT FOUND IN REPO** - แต่มีใน chat history ว่า "FIXED"

**Script:** `agents/mary_router/gateway_v3_router.py`

**Note:** ต้องตรวจสอบว่า plist file อยู่ใน `~/Library/LaunchAgents/` หรือไม่

### 7. Delegation Watchdog ✅
**Expected:** `~/Library/LaunchAgents/com.02luka.delegation-watchdog.plist`  
**Status:** ⚠️ **NOT FOUND IN REPO** - แต่มีใน chat history ว่า "FIXED"

**Script:** `hub/delegation_watchdog.mjs`

**Note:** ต้องตรวจสอบว่า plist file อยู่ใน `~/Library/LaunchAgents/` หรือไม่

### 8. CLC Executor ✅
**Expected:** `~/Library/LaunchAgents/com.02luka.clc-executor.plist`  
**Status:** ⚠️ **NOT FOUND IN REPO** - แต่มีใน chat history ว่า "FIXED"

**Script:** `agents/clc_local/clc_local.py`

**Note:** ต้องตรวจสอบว่า plist file อยู่ใน `~/Library/LaunchAgents/` หรือไม่

---

## 📊 Summary

### LaunchAgents in Repository
- **Total Found:** ~48 plist files
- **Main Locations:**
  - `LaunchAgents/` (28 files)
  - `launchd/` (6 files)
  - `Library/LaunchAgents/` (3 files)
  - Other locations (11 files)

### LaunchAgents Referenced in Chat History
- **Found in Repo:** 3/8
  - ✅ com.02luka.auto.commit.plist
  - ✅ com.02luka.git.auto.commit.ai.plist
  - ✅ com.02luka.mls.ledger.monitor.plist

- **Not Found in Repo (but mentioned as installed):** 5/8
  - ⚠️ com.02luka.pr11.healthcheck.plist
  - ⚠️ com.02luka.perf-collect-daily.plist
  - ⚠️ com.02luka.mary-coo.plist
  - ⚠️ com.02luka.delegation-watchdog.plist
  - ⚠️ com.02luka.clc-executor.plist

### Action Required
1. **Verify Installation:** ตรวจสอบว่า LaunchAgents ที่ "NOT FOUND IN REPO" อยู่ใน `~/Library/LaunchAgents/` หรือไม่
2. **Check Status:** ตรวจสอบว่า LaunchAgents ไหนที่ loaded/running
3. **Documentation:** อัปเดต LAUNCHAGENT_REGISTRY.md ให้ครบถ้วน

---

**Next:** ต้องตรวจสอบ `~/Library/LaunchAgents/` directory เพื่อยืนยันว่า LaunchAgents ไหนที่ติดตั้งแล้ว
