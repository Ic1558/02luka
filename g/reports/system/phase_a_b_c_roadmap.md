# Phase A-B-C Roadmap: System Hardening
**Generated:** 2025-12-13  
**Based on:** Phase-by-Phase Search Results (8 phases)

---

## 🎯 Overview

**Current Status:** System is functional but not fully hardened  
**Goal:** Make system production-safe and complete

**Method:** 3-phase approach to prevent chaos

---

## 🔴 Phase A: Stabilize the Floor (HIGH PRIORITY)

**Objective:** Hardening เพื่อป้องกัน workspace หายจาก git clean/reset

**Tasks:**
1. ✅ Fix guard script bug (replace `file` command)
2. ✅ Restore pre-commit hook to blocking mode
3. ✅ Complete workspace migration (4 paths → symlinks)

**Success Criteria:**
- Guard script works without errors
- Pre-commit blocks commits that violate workspace rules
- All workspace paths are symlinks pointing to ~/02luka_ws/

**Impact:** 
- ✅ `git reset --hard` will NOT delete workspace data
- ✅ `git clean -fd` will NOT delete workspace data
- ✅ Pre-commit enforces workspace rules

**Checklist:** `g/reports/system/phase_a_stabilize_checklist.md`

**Estimated Time:** 15-20 minutes

---

## 🟡 Phase B: Restore Missing Knowledge (MEDIUM PRIORITY)

**Objective:** Restore files from git history and verify missing components

**Tasks:**
1. Restore Persona Files (10 files from commit `d201db4c`)
2. Restore Governance v5 Documents (3 files from commit `35d2586f`)
3. Check workspace for PR-11 reports
4. Update reports to reflect post-restore status

**Success Criteria:**
- All 10 persona files restored
- All 3 governance v5 documents restored
- PR-11 reports location verified
- Reports updated

**Impact:**
- ✅ Persona loaders will work
- ✅ Governance v5 documentation available
- ✅ Complete knowledge base restored

**Estimated Time:** 10-15 minutes

---

## 🟢 Phase C: Lock the System (LOW PRIORITY)

**Objective:** Final hardening and policy enforcement

**Tasks:**
1. Verify guard script hard fails on violations
2. Verify pre-commit enforces rules
3. Update .cursorrules with final policies
4. Final system verification

**Success Criteria:**
- All guards working and enforcing
- All policies documented
- System verified as production-safe

**Impact:**
- ✅ System fully hardened
- ✅ Policies locked and documented
- ✅ Ready for long-term production use

**Estimated Time:** 10-15 minutes

---

## 📊 Current System Status (Fact-Based)

### ✅ Complete Systems (100%)
- Save/Seal System
- Mary Router Phase 1
- Core Scripts (12/12)

### ⚠️ Incomplete Systems (50-90%)
- Persona System: 50% (scripts exist, files need restore)
- Workspace Infrastructure: 80% (bootstrap exists, migration incomplete)
- Guard System: 90% (script exists, bug needs fix)
- Documentation: 70% (most files exist, 3 need restore)

### ❌ Missing Components
- Persona Files: 10 files (in git history)
- Governance v5 Documents: 3 files (in git history)
- PR-11 Reports: 2 reports (location unknown)
- Workspace Symlinks: 4 paths (need migration)

---

## 🎯 Decision Matrix

**If Phase A is NOT done:**
- ⚠️ Risk: Workspace data can still be lost from git operations
- ⚠️ Risk: Pre-commit doesn't enforce rules

**If Phase A is done:**
- ✅ Workspace data is safe from git operations
- ✅ Pre-commit enforces workspace rules
- ✅ System is production-safe for git operations

**If Phase B is NOT done:**
- ⚠️ Persona loaders won't work
- ⚠️ Governance v5 docs not available

**If Phase C is NOT done:**
- ⚠️ System works but not fully hardened
- ⚠️ Policies may not be fully documented

---

## 📋 Execution Order

**Recommended:** Phase A → Phase B → Phase C (sequential)

**Alternative:** Phase A only (if time-constrained)

**Not Recommended:** Skip Phase A (high risk)

---

**Status:** Ready for execution  
**Next Action:** Execute Phase A checklist
