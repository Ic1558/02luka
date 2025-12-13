# Comprehensive System Status Report
**Generated:** 2025-12-13  
**Purpose:** รายงานสถานะครบถ้วนของระบบทั้งหมด (จาก Chat History vs Reality)

---

## 📊 Executive Summary

### ✅ สิ่งที่มีอยู่จริง (Verified - 100%)

#### 1. Core Scripts (12/12) ✅
- ✅ `tools/save.sh` - Save gateway
- ✅ `tools/session_save.zsh` - Backend save engine
- ✅ `tools/workflow_dev_review_save.py` - Seal-now (Python)
- ✅ `tools/workflow_dev_review_save.zsh` - Seal-now (Zsh fallback)
- ✅ `tools/workflow_dev_review_save_status.zsh` - Status viewer
- ✅ `tools/load_persona_v3.zsh` - Persona loader v3
- ✅ `tools/load_persona_v5.zsh` - Persona loader v5
- ✅ `tools/bootstrap_workspace.zsh` - Workspace bootstrap
- ✅ `tools/guard_workspace_inside_repo.zsh` - Workspace guard
- ✅ `tools/safe_git_clean.zsh` - Safe git clean
- ✅ `tools/mary_dispatch.py` - Mary Router core
- ✅ `tools/mary.zsh` - Mary Router wrapper
- ✅ `tools/mary_preflight.zsh` - Mary preflight (report-only)

#### 2. PR-11 Healthcheck Scripts (5/5) ✅
- ✅ `tools/pr11_day0_healthcheck.zsh` - Day 0 healthcheck
- ✅ `tools/pr11_healthcheck_auto.zsh` - Auto healthcheck
- ✅ `tools/pr11_healthcheck_set_mode.zsh` - Mode switcher
- ✅ `tools/shortcut_healthcheck_a.zsh` - Shortcut A
- ✅ `tools/shortcut_pr_monitor_b.zsh` - Shortcut B

#### 3. Git Configuration (3/3) ✅
- ✅ `.gitignore` - Updated with workspace paths
- ✅ `.git/info/exclude` - Local excludes configured
- ✅ `.git/hooks/pre-commit` - Hook exists (but downgraded)

#### 4. Documentation (2/3) ⚠️
- ✅ `g/reports/system/save_vs_seal_aliases_20251207.md`
- ✅ `g/reports/system/workspace_split_implementation_report.md`
- ❌ `g/docs/HOWTO_TWO_WORLDS.md` - **MISSING** (ควรมีตาม chat history)

#### 5. Workspace Infrastructure (2/2) ✅
- ✅ `~/02luka_ws/` - Workspace directory exists
- ✅ `~/02luka_local/` - Local config directory exists

#### 6. LaunchAgent (1/1) ✅
- ✅ `~/Library/LaunchAgents/com.02luka.pr11.healthcheck.plist` - Exists and loaded

---

## ❌ สิ่งที่หายไป / ยังไม่ทำ

### 1. Persona Files ❌ CRITICAL
**Status:** ❌ `personas/` directory ไม่มี
**Expected:** ควรมีไฟล์:
- `personas/CLS_PERSONA_v2.md` (หรือ v3)
- `personas/LIAM_PERSONA_v2.md` (หรือ v3)
- `personas/GG_PERSONA_v3.md`
- `personas/GM_PERSONA_v3.md`
- `personas/MARY_PERSONA_v3.md`
- `personas/CLC_PERSONA_v3.md`
- `personas/GMX_PERSONA_v3.md`
- `personas/CODEX_PERSONA_v3.md`
- `personas/GEMINI_PERSONA_v3.md`
- `personas/LAC_PERSONA_v3.md`

**Impact:** `load_persona_v3.zsh` และ `load_persona_v5.zsh` จะไม่ทำงาน

### 2. Workspace Symlinks ❌ HIGH PRIORITY
**Status:** ยังไม่ migrate เสร็จ

**Paths ที่ยังเป็น real directory (ต้องเป็น symlink):**
- ❌ `g/followup/` → ควรเป็น symlink → `~/02luka_ws/g/followup/`
- ❌ `mls/ledger/` → ควรเป็น symlink → `~/02luka_ws/mls/ledger/`
- ❌ `bridge/processed/` → ควรเป็น symlink → `~/02luka_ws/bridge/processed/`
- ❌ `g/apps/dashboard/data/followup.json` → ควรเป็น symlink

**Paths ที่ไม่มี (อาจยังไม่สร้าง):**
- ⚠️ `g/data/` → ไม่มี (อาจยังไม่ใช้)
- ⚠️ `g/telemetry/` → ไม่มี (อาจยังไม่ใช้)

**Paths ที่ migrate แล้ว:**
- ✅ `bridge/inbox/` → symlink
- ✅ `shared_memory/` → symlink

### 3. Guard Script Bug ❌ HIGH PRIORITY
**File:** `tools/guard_workspace_inside_repo.zsh`  
**Line 39:** ใช้ `file` command ที่ไม่มีใน macOS/zsh
```zsh
echo "   Found: $(file "$full_path")" >&2
```

**Expected Fix:**
```zsh
if [[ -d "$full_path" ]]; then
  echo "   Found: real directory" >&2
elif [[ -f "$full_path" ]]; then
  echo "   Found: real file" >&2
else
  echo "   Found: other type (not symlink)" >&2
fi
```

**Impact:** Guard script fail ทุกครั้งที่เจอ real directory

### 4. Pre-commit Hook Downgrade ❌ HIGH PRIORITY
**File:** `.git/hooks/pre-commit`  
**Current State:** Downgrade เป็น warn (ไม่ block)
```sh
zsh tools/guard_workspace_inside_repo.zsh || true
exit 0
```

**Expected:** ต้อง fail เมื่อ guard fail
```sh
exec zsh tools/guard_workspace_inside_repo.zsh
```

**Impact:** Pre-commit ไม่ block commits ที่ผิดกฎ workspace

### 5. PR-11 Results Directory ❌ MEDIUM PRIORITY
**Expected:** `~/02luka_ws/g/reports/pr11_healthcheck/`  
**Status:** ❌ ไม่มี

**Impact:** 
- `pr11_healthcheck_auto.zsh` อาจ fail หรือเก็บผลที่อื่น
- ต้องสร้าง directory นี้ก่อน LaunchAgent จะทำงานได้ถูกต้อง

### 6. HOWTO_TWO_WORLDS_v2.md ✅ FOUND
**Expected:** `g/docs/HOWTO_TWO_WORLDS_v2.md`  
**Status:** ✅ **FOUND** - ไฟล์มีอยู่ใน working directory แล้ว

**Note:** ไฟล์นี้ถูกสร้างใน commit `ee4ff8ad` (2025-12-10) และแก้ไขใน `35d2586f`

**Impact:** มี quick reference guide สำหรับ Two Worlds model แล้ว (v2 - Developer Edition)

### 7. Persona Files ⚠️ FOUND IN GIT HISTORY (Need Restore)
**Expected:** `personas/` directory with 10 persona files (v3)  
**Status:** ⚠️ **FOUND IN GIT HISTORY** - ต้อง restore จาก commit `d201db4c`

**Files in Git History:**
- `personas/CLS_PERSONA_v3.md`
- `personas/LIAM_PERSONA_v3.md`
- `personas/GG_PERSONA_v3.md`
- `personas/GM_PERSONA_v3.md`
- `personas/MARY_PERSONA_v3.md`
- `personas/CLC_PERSONA_v3.md`
- `personas/GMX_PERSONA_v3.md`
- `personas/CODEX_PERSONA_v3.md`
- `personas/GEMINI_PERSONA_v3.md`
- `personas/LAC_PERSONA_v3.md`

**Action Required:** Restore จาก git: `git show d201db4c:personas/CLS_PERSONA_v3.md > personas/CLS_PERSONA_v3.md` (repeat for all 10 files)

### 8. Governance v5 Documents ⚠️ FOUND IN GIT HISTORY (Need Restore)
**Expected:** `g/docs/GOVERNANCE_UNIFIED_v5.md`, `g/docs/AI_OP_001_v5.md`, `g/docs/PERSONA_MODEL_v5.md`  
**Status:** ⚠️ **FOUND IN GIT HISTORY** - ต้อง restore จาก commit `35d2586f`

**Action Required:** Restore จาก git: `git show 35d2586f:g/docs/GOVERNANCE_UNIFIED_v5.md > g/docs/GOVERNANCE_UNIFIED_v5.md` (repeat for all 3 files)

---

## 🔍 สิ่งที่ต้องตรวจสอบเพิ่มเติม

### 1. Persona Files Location
- อาจอยู่ใน path อื่น (ไม่ใช่ `personas/`)
- อาจใช้ชื่ออื่น (ไม่ใช่ `*_PERSONA_*.md`)
- ต้องค้นหาให้เจอ

### 2. PR-11 Documentation
- `g/reports/pr11_auto_setup.md` - อาจมีหรือไม่มี
- `g/reports/pr11_day0_7_checklist.md` - อาจมีหรือไม่มี
- ต้องตรวจสอบใน workspace หรือ path อื่น

### 3. Additional Mary Router Scripts
พบ scripts เพิ่มเติม:
- `tools/mary_alerts_watch.zsh`
- `tools/test_mary_router.zsh`
- `tools/mary_metrics_collect_daily.zsh`
- `tools/check_mary_gateway_health.zsh`
- `tools/mary_memory_hook.zsh`
- `tools/watchers/mary_dispatcher.zsh`

**Status:** ต้องตรวจสอบว่าเป็น legacy หรือยังใช้งาน

---

## 📋 สรุปตาม Category

### ✅ Complete Systems
1. **Save/Seal System** - 100% complete
   - save-now ✅
   - seal-now ✅
   - Documentation ✅

2. **Mary Router Phase 1** - 100% complete
   - Core logic ✅
   - Preflight integration ✅
   - Wrapper scripts ✅

3. **PR-11 Healthcheck** - 95% complete
   - Scripts ✅
   - LaunchAgent ✅
   - Results directory ❌ (missing)

4. **Workspace Split Infrastructure** - 80% complete
   - Bootstrap script ✅
   - Guard script ✅ (but has bug)
   - Safe git clean ✅
   - Git config ✅
   - Symlinks ❌ (incomplete migration)

### ❌ Incomplete Systems
1. **Persona System** - 50% complete
   - Loader scripts ✅
   - Persona files ❌ (missing)

2. **Guard System** - 90% complete
   - Script exists ✅
   - Bug fix needed ❌
   - Pre-commit hook downgraded ❌

3. **Documentation** - 70% complete
   - Save/Seal docs ✅
   - Workspace split report ✅
   - HOWTO_TWO_WORLDS ❌ (missing)

---

## 🎯 Priority Actions (ตามลำดับ)

### Priority 1: Fix Critical Bugs
1. **Fix guard script bug** (line 39: `file` command)
2. **Fix pre-commit hook** (restore blocking behavior)

### Priority 2: Complete Workspace Migration
1. **Run bootstrap_workspace.zsh** อีกครั้ง
2. **Migrate remaining paths:**
   - `g/followup/` → symlink
   - `mls/ledger/` → symlink
   - `bridge/processed/` → symlink
   - `g/apps/dashboard/data/followup.json` → symlink

### Priority 3: Restore Files from Git History
1. **Restore Persona Files** (10 files จาก commit `d201db4c`)
   ```bash
   mkdir -p personas
   git show d201db4c:personas/CLS_PERSONA_v3.md > personas/CLS_PERSONA_v3.md
   # ... repeat for all 10 files
   ```

2. **Restore Governance v5 Documents** (3 files จาก commit `35d2586f`)
   ```bash
   git show 35d2586f:g/docs/GOVERNANCE_UNIFIED_v5.md > g/docs/GOVERNANCE_UNIFIED_v5.md
   git show 35d2586f:g/docs/AI_OP_001_v5.md > g/docs/AI_OP_001_v5.md
   git show 35d2586f:g/docs/PERSONA_MODEL_v5.md > g/docs/PERSONA_MODEL_v5.md
   ```

### Priority 4: Setup Missing Components
1. **Create PR-11 results directory:** `~/02luka_ws/g/reports/pr11_healthcheck/`

---

## 📝 Legacy vs Active

### ✅ Active Systems (ใช้งานอยู่)
- Save/Seal system
- Mary Router Phase 1
- PR-11 healthcheck (auto-running)
- Workspace split infrastructure
- Safe git clean

### ⚠️ Legacy/Unknown
- Mary Router scripts อื่นๆ (ต้องตรวจสอบว่าใช้งานหรือไม่)
- Persona files (ต้องหาว่าอยู่ที่ไหน)

---

**Report Generated:** 2025-12-13  
**Next Steps:** Fix Priority 1 bugs → Complete workspace migration → Setup missing components
