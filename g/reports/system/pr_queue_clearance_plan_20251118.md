# PR Queue Clearance Plan - Systematic Solution

**Date:** 2025-11-18  
**Status:** 📋 **PLAN CREATED**  
**Approach:** Systematic, step-by-step clearance

---

## Executive Summary

**Goal:** Clear PR queue by resolving conflicts, restoring security (LPE ACL), and closing legacy PRs.

**Strategy:**
1. ✅ Easy PRs first (#359)
2. ✅ Define SOT for core components (LPE, Mary, MLS)
3. ✅ Rebase conflicting PRs (#358, #360, #361, #363)
4. ✅ Remove noise (operational reports/logs)
5. ✅ Close legacy branches

---

## Phase 0: Overall Goals

### 1. Clear Branch Drift / Conflicts
- Resolve conflicts around LPE + Mary + Context Protocol
- Establish clear SOT for each component

### 2. Restore Security & Stability
- **LPE Path ACL** - Non-negotiable security layer
- **Mary Dispatcher** - Robust dependency handling
- **MLS Ledger** - Consistent schema

### 3. Close Legacy PRs
- Close old PRs with failing CI unrelated to current state
- Clean up legacy branches

---

## Phase 1: Work Sequence (Must Follow This Order)

### ✅ Step 1 - Clear Easy PRs First

**PR #359 - LaunchAgent Runtime Validator**
- **Status:** Standalone, no conflicts
- **Action:** Merge immediately after code review
- **Benefit:** Establishes validator SOT for other PRs to reference

### ✅ Step 2 - Fix Core Components on Main

**Define SOT for:**
1. **LPE Worker** - Must include path ACL + allow list
2. **Mary Dispatcher** - Must handle missing dependencies gracefully
3. **MLS Ledger Schema** - Must match existing JSONL format

**Action:** Create/update these components on main as authoritative versions

### ✅ Step 3 - Rebase Conflicting PRs

**PRs to rebase (in order):**
- #358 - Phase 3 Completion
- #360 - LPE Worker & Filesystem Bridge
- #361 - LPE CLI & SIP Helper
- #363 - LPE Wiring & Smoke Tests

**Strategy:** Rebase each on main after Step 2 completes

### ✅ Step 4 - Remove Noise

**Action:** Remove from all PRs:
- Operational reports (`g/reports/mcp_health/*`)
- Session logs
- Generated files
- Temporary files

### ✅ Step 5 - Close Legacy Branches

**Action:** Close/archive:
- `launchagent-fix-from-main` branch
- Any PRs superseded by newer work

---

## Phase 2: Per-PR Solutions

### 🟩 PR #359 - LaunchAgent Runtime Validator

**Status:** ✅ EASY - Do First

**Issues:**
- No conflicts
- Standalone feature
- Only touches `tools/validator` + reports

**Solution:**
1. Code review (verify no governance conflicts)
2. Run tests if available
3. Merge to main immediately

**Benefit:** Establishes validator SOT for other PRs

**Files:**
- `tools/validate_launchagents.zsh`
- Reports in `g/reports/system/launchagents/`

---

### 🟧 PR #358 - Phase 3 Completion

**Status:** ⚠️ CONFLICTS - Needs Rebase

**Issues:**
1. Conflicts with core files:
   - `g/tools/lpe_worker.zsh`
   - `tools/watchers/mary_dispatcher.zsh`
2. Noise files:
   - `g/reports/mcp_health/*`
   - Session logs

**Solution:**
1. **Wait for:** #359 merge + Step 2 (SOT definition)
2. **Rebase** with main
3. **Remove noise:**
   ```bash
   git rm g/reports/mcp_health/*
   git rm **/session_logs/*
   ```
4. **Resolve conflicts:**
   - Use main as base for `lpe_worker.zsh` and `mary_dispatcher.zsh`
   - Cherry-pick only new logic from #358 (logging, comments, minor refactor)
5. **Test:** Run CI, verify no Phase 3 regressions

**Files to Handle:**
- Core: `g/tools/lpe_worker.zsh`, `tools/watchers/mary_dispatcher.zsh`
- Noise: `g/reports/mcp_health/*`, session logs

---

### 🟥 PR #360 - LPE Worker & Filesystem Bridge

**Status:** 🔴 CRITICAL - Security Regression

**Issues:**
1. **Removed path ACL** - Security regression
2. Conflicts with `g/tools/lpe_worker.zsh`

**Solution: "LPE Safety First"**

1. **Define SOT on main:**
   - LPE worker must have:
     - Path ACL check
     - Allow list of directories
     - `parse_work_order` validation:
       - Reject paths outside `$BASE`
       - Respect `path_acl`, `allow_create`, `allow_delete` in WO

2. **Rebase #360:**
   - Use main's LPE worker as base
   - Review diff for new logic:
     - If new logic doesn't break ACL → merge
     - If new logic bypasses ACL → fix to use ACL layer

3. **Verification (MUST PASS):**
   - ✅ Every patch must pass ACL check
   - ✅ No path can be modified outside allow list
   - ✅ All patches go through ACL layer

**Files:**
- `g/tools/lpe_worker.zsh` (must preserve ACL)

---

### 🟧 PR #361 - LPE CLI & SIP Helper

**Status:** ⚠️ CONFLICTS - Interface Sync Needed

**Issues:**
1. Conflicts with #360 (same interface: `lpe_worker.zsh`, CLI hooks)
2. Worker/CLI not synchronized

**Solution:**
1. **Wait for:** #360 merge (LPE worker SOT established)
2. **Rebase #361** on main
3. **Verify interface sync:**
   - `luka_cli.zsh` and `lpe_worker.zsh` use same interface
   - Arguments/flags consistent (e.g., `lpe-apply --file`)
   - CLI doesn't bypass SIP
   - All patches use same SIP helper / `apply_patch` layer

4. **If logic overlaps heavily:** Consider merging #360 + #361 into single PR

**Files:**
- `tools/luka_cli.zsh`
- `g/tools/lpe_worker.zsh`
- CLI hooks

---

### 🟥 PR #363 - LPE Wiring & Smoke Tests

**Status:** 🔴 CRITICAL - 3 Major Issues

**Issues:**

1. **LPE Worker Rewrite Removed ACL** - Security regression
2. **Mary Dispatcher PyYAML Dependency** - Crashes if PyYAML missing
3. **MLS Ledger Schema Mismatch** - Doesn't match existing JSONL

**Solution:**

#### 1) LPE ACL Fix
- Use SOT LPE worker from main (after #360 fix)
- #363 should only add:
  - Wiring hooks
  - Smoke tests
  - **NOT modify ACL logic**

#### 2) Mary + PyYAML Fix
**File:** `tools/watchers/mary_dispatcher.zsh`

**Add guard:**
```bash
if python3 -c 'import yaml' 2>/dev/null; then
  # Use PyYAML
  parse_yaml_with_pyyaml() { ... }
else
  # Fallback: use python3 + json or yq
  # Log error but exit 0 (don't crash system)
  log_error "PyYAML not available, using fallback parser"
  parse_yaml_fallback() { ... }
fi
```

**Goal:** Never crash due to missing PyYAML → downgrade feature + log

#### 3) MLS Ledger Schema Fix
**File:** `append_mls_ledger.py` (or equivalent)

**Action:**
1. Check existing MLS JSONL format (SOT):
   ```json
   {
     "type": "improvement",
     "title": "...",
     "summary": "...",
     "source": { "producer": "lpe_worker", ... },
     "tags": ["lpe", "patch"],
     "links": {...}
   }
   ```

2. Update `append_mls_ledger.py` to match this format

3. **If schema change needed:**
   - Add `schema_version: 2`
   - Update all consumers:
     - `mls_report`
     - Dashboard
     - Other readers

**Files:**
- `tools/watchers/mary_dispatcher.zsh` (PyYAML guard)
- `append_mls_ledger.py` (schema fix)
- `g/tools/lpe_worker.zsh` (use SOT, don't modify ACL)

---

### 🟨 Legacy Branch: launchagent-fix-from-main

**Status:** ⚠️ LEGACY - Clean Up

**Issues:**
- CI fails (old branch)
- Still shows "red" in PR list

**Options:**

1. **If logic migrated:**
   - Close PR/branch
   - Archive

2. **If still needed:**
   - Rebase on main
   - Remove parts already in Phase 2.2/3
   - Create new small PR with only remaining diff

---

## Phase 3: Cross-Cutting Fixes (Critical)

### 1. LPE Path ACL = Non-Negotiable

**Rule:** No version of `lpe_worker.zsh` can apply patches without path check

**SOT:** Main branch after #360 fix

**Requirements:**
- Path ACL check before any patch
- Allow list enforcement
- Reject paths outside `$BASE`

### 2. Mary Dispatcher = Robust

**Rule:** Parser must guard all dependencies

**Requirements:**
- Check for PyYAML before use
- Fallback if missing
- Never crash system due to missing dependency
- Log errors gracefully

### 3. MLS Ledger = Single Schema

**Rule:** `append_mls_ledger.py` must align with existing ledger

**Requirements:**
- Match existing JSONL format
- If changing → declare version + migrate tools
- Update all consumers

---

## Phase 4: Concrete Next Steps

### Immediate Actions (This Session)

1. **Code Review PR #359**
   - Verify no conflicts
   - Check governance compliance
   - Approve for merge

2. **Define SOT Components**
   - Review current LPE worker on main
   - Document required ACL checks
   - Document Mary dispatcher dependency handling
   - Document MLS ledger schema

3. **Create Fix PRs**
   - PR for LPE ACL enforcement (if needed)
   - PR for Mary PyYAML guard (if needed)
   - PR for MLS schema alignment (if needed)

### Next Session Actions

1. **Merge #359** (after review)
2. **Merge SOT fixes** to main
3. **Rebase #358** → merge
4. **Fix #360** (ACL) → merge
5. **Sync #361** (interface) → merge
6. **Fix #363** (3 issues) → merge
7. **Close legacy branches**

---

## Verification Checklist

### Before Merging Any PR:

- [ ] No security regressions (LPE ACL intact)
- [ ] No dependency crashes (Mary handles missing deps)
- [ ] Schema consistency (MLS matches existing)
- [ ] No noise files (reports/logs removed)
- [ ] CI passes
- [ ] Code review complete

### After Each Merge:

- [ ] Verify SOT updated
- [ ] Update dependent PRs
- [ ] Document changes

---

## Status Tracking

**Current Status:**
- ✅ Plan created
- ⏳ PR #359 review pending
- ⏳ SOT definition pending
- ⏳ PR #358-363 fixes pending

**Next:** Code review PR #359 and define SOT components

---

**Created:** 2025-11-18  
**Status:** Ready for execution
