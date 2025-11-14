# Extract: CODEX, SYNC, CRITICAL Topics
**Source:** `/Users/icmini/LocalProjects/02luka-memory/Boss/Chat archive/cls_251113-4.md`  
**Date:** 2025-11-14  
**Purpose:** Key findings on codex, sync, and critical topics

---

## 🔍 CODEX Topics

### Files & References
1. **WO-251112-CLAUDE-PHASE2_6-CODEX.zsh** - Work order for Codex phase 2.6
2. **MLS Status Files:**
   - `mls/status/251110_ci_cls_codex_summary.json`
   - `mls/status/251111_ci_cls_codex_summary.json`
   - `mls/status/251112_ci_cls_codex_summary.json`
   - `mls/status/251113_ci_cls_codex_summary.json`

### Key Mentions
- **Codex directory movement:** "Codex เคลื่อนย้าย directory (ไม่ได้ลบ)"
- **Codex extract folder:** Mentioned in file structure discussions
- **Pipeline v2 / Codex work:** "Pipeline v2 / ของใหม่ที่ Codex ทำ"
- **Codex cleanup option:** "ถ้าไม่ชอบของ Codex ชุดนี้ทีหลัง → ลบทิ้ง branch เดียวจบ"
- **CLC/Codex delegation:** "CLC / Codex ต่อ" (for CLS.md revision tasks)

### ⚠️ CRITICAL CODEX Issue
**Most Important Finding:**
```
9bf8hk'ginjv'cdh CRITICAL CODEX > GITHUB ยังไม่ได้ตรวจสอบ ตอนนี้เลยยังไม่ได้ sync
```

**Context:**
- Note recorded: 2025-11-14
- Status: Pending verification
- Impact: GitHub sync blocked until Codex verification complete
- Related: "do not forget now we are not trying to sync regarding to latest codex ide"

---

## 🔄 SYNC Topics

### Sync Status & Recovery
1. **Auto-sync disabled** - During emergency recovery
2. **Cursor Editor behavior:**
   - "Cursor Explorer ยังเห็นไฟล์ครบ (เพราะ Editor memory + ไม่ sync)"
   - "ไม่ได้ sync ทุกการลบจาก Git"
   - Editor uses memory filesystem cache, doesn't sync all Git deletions

### Sync Plans & Reports
- `reports/sync_filtered_sorted_20251113.md`
- `reports/sync_plan_20251113.md`
- `reports/feature_system_truth_sync_PLAN.md`

### Sync Tools (Deleted/Restored)
- `tools/bridge_knowledge_sync.zsh`
- `tools/ensure_remote_sync.zsh`
- `tools/gc_memory_sync.sh`
- `tools/hub_sync.zsh`
- `tools/mem_sync_from_core.zsh`
- `tools/memory_sync.sh`
- `tools/telemetry_sync.zsh`

### Git Sync Re-enablement Discussion
**Key Question:** "go no go to back to sync git?"

**Recommendations:**
- Use `ai/` branch for sync (not `main`)
- Auto-commit but manual push approval
- Safety checks: branch protection, SOT warnings, dry-run mode
- "ล้าง local → sync จาก remote → เริ่มทำงานจาก repo ที่สะอาด"

### ⚠️ CRITICAL SYNC Issue
**Blocked by Codex verification:**
```
CRITICAL CODEX > GITHUB ยังไม่ได้ตรวจสอบ ตอนนี้เลยยังไม่ได้ sync
```

---

## ⚠️ CRITICAL Topics

### Critical Issues Resolved
- **Recovery Status:** ✅ COMPLETE - OPTION C SUCCESS
- **All Critical Issues Resolved:**
  - ✅ Repository healthy (on branch, not detached)
  - ✅ Pipeline v2 safely restored and committed
  - ✅ Multiple backup layers preserved
  - ✅ Ready for PR/review

### Critical Files
- `g/reports/mls_ledger_critical_protection_20251113.md`
- `g/reports/mls_ledger_disappearing_issue_20251113.md`

### Critical Patterns & Behaviors

#### 1. Log File Reading (CRITICAL)
**Pattern:**
1. Script executed → Check for log file in `g/reports/*_LOG.txt` or `logs/`
2. If log exists → Read directly with `read_file` tool
3. Verify execution from log content
4. Never claim "can't see terminal output" if log exists

#### 2. Self-Awareness (CRITICAL)
**When you don't know or can't verify:**
1. State limitation explicitly
2. Suggest verification method
3. Don't guess or assume

#### 3. Promise-Verify Pattern (CRITICAL)
- Never promise WO then fix directly
- Verify WO file exists after creation
- Log to MLS after verification

#### 4. Critical Insight - MLS Lessons
**Two requirements for useful lessons:**
1. **Must be in MLS** - Otherwise CLS won't remember
2. **Must be used by CLS** - Otherwise they're just documentation

**Lessons will be useful when:**
1. Recorded to MLS (so CLS can remember)
2. CLS must actually use them (not just documented)

### Critical Sections in Code
- **Lines 128-136:** `git reset --hard` - Only executes in LIVE mode
- **Lines 45-60:** Untracked file backup - Fixed whitespace handling
- **Lines 108-125:** Branch switching - Handles conflicts

### Critical Decision Patterns
- **WO Creation Rule:** 0-1 critical issues → Fix directly, 2+ → Create WO
- **Verification:** Always read log files before claiming no output
- **MLS Integration:** Check MLS before similar mistakes
- **Evidence-Based:** SHA256, timestamps, validation

---

## 🎯 Key Takeaways

### Immediate Actions Needed
1. **⚠️ CRITICAL:** Verify Codex changes before enabling GitHub sync
2. **⚠️ CRITICAL:** Review Codex directory movements and extract folders
3. **⚠️ CRITICAL:** Check MLS status files for Codex summaries

### Sync Strategy
- Use `ai/` branch for auto-commit
- Manual push approval required
- Safety checks: branch protection, SOT warnings, dry-run mode
- **Blocked until Codex verification complete**

### Critical Behaviors to Enforce
1. Always read log files directly (never claim "no output" if log exists)
2. Check MLS before similar actions
3. Follow WO decision pattern (0-1 → fix, 2+ → WO)
4. Verify promises (WO file exists, log to MLS)

---

## 📝 Related Notes in MLS Ledger

From `mls/ledger/2025-11-14.jsonl`:
1. **CRITICAL CODEX > GITHUB sync status**
   - Tags: critical, codex, github, sync, pending
   - Summary: "9bf8hk'ginjv'cdh CRITICAL CODEX > GITHUB ยังไม่ได้ตรวจสอบ ตอนนี้เลยยังไม่ได้ sync"

2. **System Truth Sync - Next Steps (Pending)**
   - Tags: wo, pending, system-truth-sync, next-steps, mary-dispatcher, clc

---

**Generated:** 2025-11-14  
**Status:** Extract complete - Ready for review
