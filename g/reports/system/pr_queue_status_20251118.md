# PR Queue Status - Current Reality Check

**Date:** 2025-11-18  
**Status:** 📊 **STATUS ASSESSMENT**

---

## Key Finding: Many PRs Already Merged!

### ✅ Already Merged PRs

1. **PR #359** - LaunchAgent Runtime Validator ✅ MERGED
   - Status: Already in main
   - Action: None needed

2. **PR #360** - LPE Worker & Filesystem Bridge ✅ MERGED
   - Status: Already in main
   - **⚠️ Need to verify:** Path ACL still intact

3. **PR #361** - LPE CLI & SIP Helper ✅ MERGED
   - Status: Already in main
   - **⚠️ Need to verify:** Interface sync with #360

4. **PR #363** - LPE Wiring & Smoke Tests ✅ MERGED
   - Status: Already in main
   - **⚠️ Need to verify:** 
     - ACL not removed
     - PyYAML dependency handled
     - MLS schema correct

---

## ⚠️ Open PRs with Issues

### 🔴 PR #358 - Phase 3 Completion

**Status:** OPEN, CONFLICTING/DIRTY  
**Files:** 100 files changed  
**Issues:**
- Conflicts with main
- May have noise files (reports/logs)

**Action Required:**
1. Check what conflicts exist
2. Remove noise files
3. Resolve conflicts
4. Rebase on main

---

### 🔴 PR #368 - Dashboard Features (Our New PR)

**Status:** OPEN, CONFLICTING/DIRTY  
**Files:** 10 files changed  
**Issues:**
- Merge conflicts with main
- Need to rebase

**Action Required:**
1. Rebase on main
2. Resolve conflicts
3. Push updated branch

---

## Verification Needed

### 1. LPE Path ACL Security ✅/❌

**Check:** Verify merged PRs (#360, #363) didn't remove ACL

**Action:**
- Review `g/tools/lpe_worker.zsh` (or equivalent) on main
- Verify path ACL checks exist
- Verify allow list enforcement

### 2. Mary Dispatcher Robustness ✅/❌

**Check:** Verify PyYAML dependency is handled gracefully

**Action:**
- Review `tools/watchers/mary_dispatcher.zsh` on main
- Check for dependency guards
- Verify fallback behavior

### 3. MLS Ledger Schema ✅/❌

**Check:** Verify schema matches existing JSONL

**Action:**
- Review MLS JSONL format on main
- Check any append/write scripts
- Verify schema consistency

---

## Updated Action Plan

### Immediate Actions

1. **Verify Merged PRs** (Critical)
   - Check LPE ACL on main
   - Check Mary dispatcher dependencies
   - Check MLS schema

2. **Fix PR #358**
   - Resolve conflicts
   - Remove noise
   - Rebase on main

3. **Fix PR #368**
   - Resolve conflicts
   - Rebase on main

### If Security Issues Found

1. **Create hotfix PRs** to restore:
   - LPE path ACL
   - Mary dependency guards
   - MLS schema alignment

2. **Priority:** Security fixes first, then conflicts

---

**Status:** Assessment complete, verification needed  
**Next:** Verify merged PRs didn't introduce regressions

