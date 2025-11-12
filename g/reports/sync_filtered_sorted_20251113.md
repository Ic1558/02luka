# Sync Plan - Filtered and Sorted

**Date:** 2025-11-13  
**Total Changes:** 14 modified, 32 new, 1 deleted

---

## 🔴 PRIORITY 1: Critical MLS Schema Fixes (MUST SYNC)

**Files:**
- `.github/workflows/cls-ci.yml` - Removed artifact_size, added cleaning
- `.github/workflows/bridge-selfcheck.yml` - Removed artifact_size, added cleaning
- `mls/ledger/2025-11-12.jsonl` - Removed artifact_size
- `mls/ledger/2025-11-13.jsonl` - Schema compliant

**Command:**
```bash
git add .github/workflows/cls-ci.yml .github/workflows/bridge-selfcheck.yml
git add mls/ledger/2025-11-12.jsonl mls/ledger/2025-11-13.jsonl
git commit -m "fix(mls): remove artifact_size schema violation, add cleaning step"
```

**Why Critical:** Prevents schema validation failures, ensures MLS integrity

---

## 🟠 PRIORITY 2: MLS Protection Tools (SHOULD SYNC)

**Files:**
- `tools/mls_ledger_protect.zsh` - Validation, backup, recovery
- `tools/mls_ledger_monitor.zsh` - Hourly monitoring
- `tools/mls_status_summary_update.zsh` - Auto-update summaries
- `Library/LaunchAgents/com.02luka.mls.ledger.monitor.plist` - LaunchAgent
- `.git/hooks/pre-commit-mls-protect` - Pre-commit hook

**Command:**
```bash
git add tools/mls_ledger_protect.zsh tools/mls_ledger_monitor.zsh tools/mls_status_summary_update.zsh
git add Library/LaunchAgents/com.02luka.mls.ledger.monitor.plist
git add .git/hooks/pre-commit-mls-protect
git commit -m "feat(mls): add ledger protection and monitoring tools"
```

**Why Important:** Ensures MLS ledger reliability, prevents corruption

---

## 🟡 PRIORITY 3: MLS Status Files (SHOULD SYNC)

**Files:**
- `mls/status/251113_ci_cls_codex_summary.json` - Today's summary
- `mls/status/251113_ci_cls_codex_summary.yml` - YAML version

**Command:**
```bash
git add mls/status/251113_ci_cls_codex_summary.json mls/status/251113_ci_cls_codex_summary.yml
git commit -m "feat(mls): add status summary auto-update"
```

**Why Important:** Status summaries for visibility

---

## 🟢 PRIORITY 4: MLS Documentation (SHOULD SYNC)

**Files:**
- `g/reports/mls_artifact_size_verification_20251113.md`
- `g/reports/mls_bugs_fixed_20251113.md`
- `g/reports/mls_ledger_critical_protection_20251113.md`
- `g/reports/mls_ledger_disappearing_issue_20251113.md`
- `g/reports/mls_ledger_protection_complete_20251113.md`
- `g/reports/mls_schema_fix_artifact_size_20251113.md`
- `g/reports/mls_self_learning_fix_20251113.md`
- `g/reports/mls_status_summary_auto_update_fix_20251113.md`
- `g/reports/mls_status_summary_root_cause_20251113.md`
- `g/reports/sync_plan_20251113.md`
- `g/reports/sync_filtered_sorted_20251113.md`

**Command:**
```bash
git add g/reports/mls_*.md g/reports/sync_*.md
git commit -m "docs(mls): document fixes and root cause analysis"
```

**Why Important:** Documents fixes for future reference

---

## 🔵 PRIORITY 5: Configuration (SHOULD SYNC)

**Files:**
- `.cursorrules` - Added WO Creation Decision Pattern

**Command:**
```bash
git add .cursorrules
git commit -m "docs: add WO creation decision pattern"
```

**Why Important:** Documents critical decision pattern

---

## ⚠️ REVIEW BEFORE SYNC

### Auto-generated Files (May Skip)
- `g/knowledge/mls_index.json` - Auto-updated by MLS
- `g/knowledge/mls_lessons.jsonl` - Auto-updated by MLS
- `g/telemetry/unified.jsonl` - Auto-generated

### Dashboard Data (Check if Auto-generated)
- `g/apps/dashboard/data/followup.json` - Empty items array

### Deleted Files (Verify Intentional)
- `bridge/inbox/ENTRY/WO-251112-014650-auto.yaml` - Deleted
- Check if moved to `bridge/inbox/CLC/WO-251112-014650-auto.yaml`

### Replaced Files (Verify Intentional)
- `g/reports/feature_claude_code_week3_4_docs_monitoring_SPEC.md` - Replaced with shell script

### Backup Files (Should Exclude)
- `mls/ledger/2025-11-13.jsonl.corrupted-backup` - Backup file

### Log Files (Should Exclude)
- `logs/n8n.launchd.err` - Log file

---

## ❌ EXCLUDE FROM SYNC

### Backup Files
- `mls/ledger/2025-11-13.jsonl.corrupted-backup`

### Log Files
- `logs/n8n.launchd.err`

### Auto-generated (Review)
- `g/knowledge/mls_index.json`
- `g/knowledge/mls_lessons.jsonl`
- `g/telemetry/unified.jsonl`

---

## 📋 Quick Sync Commands

### All Critical + Important (Recommended)
```bash
# Priority 1-5
git add .github/workflows/cls-ci.yml .github/workflows/bridge-selfcheck.yml
git add mls/ledger/2025-11-12.jsonl mls/ledger/2025-11-13.jsonl
git add tools/mls_ledger_protect.zsh tools/mls_ledger_monitor.zsh tools/mls_status_summary_update.zsh
git add Library/LaunchAgents/com.02luka.mls.ledger.monitor.plist
git add .git/hooks/pre-commit-mls-protect
git add mls/status/251113_ci_cls_codex_summary.json mls/status/251113_ci_cls_codex_summary.yml
git add g/reports/mls_*.md g/reports/sync_*.md
git add .cursorrules
git commit -m "fix(mls): schema compliance, protection tools, and documentation"
```

### Critical Only (Minimum)
```bash
git add .github/workflows/cls-ci.yml .github/workflows/bridge-selfcheck.yml
git add mls/ledger/2025-11-12.jsonl mls/ledger/2025-11-13.jsonl
git commit -m "fix(mls): remove artifact_size schema violation"
```

---

## 📊 Summary

**Must Sync (Critical):** 4 files  
**Should Sync (Important):** ~20 files  
**Review Before Sync:** 5 files  
**Exclude:** 3 files  

**Total Recommended:** ~24 files  
**Total Changes:** 47 files (14 modified + 32 new + 1 deleted)

---

**Status:** ✅ Ready for sync (priorities 1-5)
