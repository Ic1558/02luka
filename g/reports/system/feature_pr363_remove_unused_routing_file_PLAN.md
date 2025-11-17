# Feature Plan: Remove Unused Routing Rules File from PR #363

**Feature:** `fix(pr363): remove unused routing_rules.yaml file`  
**Priority:** P1 (Blocking PR #363 merge)  
**Date:** 2025-11-18  
**Author:** Andy (Codex Layer 4)  
**Status:** 📋 Planning

---

## 1. Scope & Purpose

### Goal

Remove the unused `g/config/orchestrator/routing_rules.yaml` file from PR #363 because:
- It's not used by the dispatcher (dispatcher reads from `wo_routing_rules.yaml`)
- It has wrong format (doesn't match dispatcher expectations)
- It's redundant (correct routing rule already exists)

### Why

**Problem:**
- PR #363 adds `g/config/orchestrator/routing_rules.yaml` with incorrect format
- Dispatcher (`tools/watchers/mary_dispatcher.zsh`) reads from `g/config/wo_routing_rules.yaml` instead
- The new file format doesn't match dispatcher expectations
- Creates confusion about which file is the source of truth

**Impact:**
- No functional impact (file is unused)
- Code review flagged as P1 issue
- Blocks PR #363 merge readiness

### Success Criteria

- ✅ Unused file removed from PR #363
- ✅ Dispatcher confirmed to use `wo_routing_rules.yaml` correctly
- ✅ Routing functionality verified (already working)
- ✅ PR #363 ready for merge

---

## 2. Specification

### 2.1 Files to Modify

1. **PR #363 Branch** (`codex/add-lpe-worker-and-launchagent-s0m00i`)
   - Remove: `g/config/orchestrator/routing_rules.yaml`

### 2.2 Current State

**File to Remove:**
```yaml
# g/config/orchestrator/routing_rules.yaml (WRONG FORMAT, NOT USED)
rules:
  - name: write-to-lpe
    when:
      task.type: "write"
      fallback: "lpe"    # ❌ Wrong format
    route: "LPE"
```

**File Actually Used:**
```yaml
# g/config/wo_routing_rules.yaml (CORRECT FORMAT, USED BY DISPATCHER)
routes:
  - name: lpe-write-fallback
    match:
      task_type: write        # ✅ Correct format
      fallback_contains: lpe  # ✅ Correct format
    target: LPE               # ✅ Correct format
```

**Dispatcher Code:**
```bash
# tools/watchers/mary_dispatcher.zsh
ROUTING_RULES="$ROOT/g/config/wo_routing_rules.yaml"  # ✅ Uses wo_routing_rules.yaml
```

### 2.3 Changes Required

**Change 1: Remove Unused File**

**Action:** Delete `g/config/orchestrator/routing_rules.yaml` from PR #363 branch

**Reason:**
1. Dispatcher reads from `g/config/wo_routing_rules.yaml` (line 11 of mary_dispatcher.zsh)
2. Dispatcher already has correct LPE routing rule in `wo_routing_rules.yaml`
3. The new file format doesn't match dispatcher expectations
4. Routing works correctly with existing file

**Verification:**
- Confirm dispatcher uses `wo_routing_rules.yaml` (already verified)
- Confirm LPE routing works (already working)
- Confirm no references to `orchestrator/routing_rules.yaml` in codebase

---

## 3. Task Breakdown

### Phase 1: Verification

- [x] Verify dispatcher reads from `wo_routing_rules.yaml`
- [x] Verify LPE routing rule exists in `wo_routing_rules.yaml`
- [x] Verify new file format doesn't match dispatcher
- [ ] Check for any references to `orchestrator/routing_rules.yaml` in codebase

### Phase 2: Implementation

- [ ] Checkout PR #363 branch
- [ ] Remove `g/config/orchestrator/routing_rules.yaml`
- [ ] Verify no broken references
- [ ] Commit change

### Phase 3: Testing

- [ ] Verify dispatcher still works (reads from `wo_routing_rules.yaml`)
- [ ] Verify LPE routing still works
- [ ] Run smoke test (if applicable)
- [ ] Check CI passes

### Phase 4: PR Update

- [ ] Update PR description (clarify routing uses existing file)
- [ ] Push changes to PR branch
- [ ] Verify PR status (should remain MERGEABLE)

---

## 4. Test Strategy

### 4.1 Verification Tests

**Test 1: Dispatcher File Reference**
```bash
# Verify dispatcher uses correct file
grep -n "wo_routing_rules.yaml" tools/watchers/mary_dispatcher.zsh
# Expected: Line 11 shows ROUTING_RULES="$ROOT/g/config/wo_routing_rules.yaml"
```

**Test 2: LPE Routing Rule Exists**
```bash
# Verify LPE rule in correct file
grep -A 5 "lpe-write-fallback" g/config/wo_routing_rules.yaml
# Expected: Rule exists with correct format
```

**Test 3: No References to Removed File**
```bash
# Verify no code references removed file
grep -r "orchestrator/routing_rules.yaml" . --exclude-dir=.git
# Expected: No matches (file not referenced)
```

### 4.2 Functional Tests

**Test 4: Routing Still Works**
- Dispatcher reads from `wo_routing_rules.yaml` ✅ (already verified)
- LPE routing rule matches correctly ✅ (already verified)
- Worker receives routed WOs ✅ (already verified)

### 4.3 CI Tests

- [ ] All existing CI checks pass
- [ ] No new linting errors
- [ ] No broken file references

---

## 5. Implementation Notes

### 5.1 Why This File Exists

**Hypothesis:** The file was added during development but:
- Dispatcher was already updated to use `wo_routing_rules.yaml`
- The new file format was never integrated into dispatcher
- It became orphaned code

### 5.2 Why Remove (Not Fix)

**Option 1: Remove File** ✅ (Recommended)
- Simpler (one file deletion)
- No code changes needed
- Routing already works correctly
- Less maintenance burden

**Option 2: Fix File Format** ❌ (Not recommended)
- Would require updating dispatcher to read new file
- More complex (multiple file changes)
- Unnecessary (existing file works)
- Higher risk of breaking existing functionality

### 5.3 Risk Assessment

**Low Risk:**
- File is unused (no functional impact)
- Simple deletion (no code changes)
- Routing already works correctly

**Mitigation:**
- Verify dispatcher file reference before deletion
- Verify routing still works after deletion
- Run CI checks

---

## 6. PR Description Update

After fix, update PR #363 description to clarify:

```markdown
### Routing Configuration

- LPE routing uses existing `g/config/wo_routing_rules.yaml` file
- Dispatcher (`tools/watchers/mary_dispatcher.zsh`) reads from `wo_routing_rules.yaml`
- LPE routing rule: `lpe-write-fallback` (matches `task_type: write` + `fallback_contains: lpe`)
- No new routing config files added (uses existing infrastructure)
```

---

## 7. Success Metrics

- ✅ Unused file removed
- ✅ Dispatcher confirmed to use correct file
- ✅ Routing functionality verified
- ✅ CI checks pass
- ✅ PR #363 ready for merge

---

## 8. Rollback Plan

If issues arise:
1. Re-add the file (git restore)
2. Investigate why routing broke
3. Fix actual issue
4. Re-remove file if still unused

**Note:** Rollback unlikely since file is unused.

---

## 9. Dependencies

- PR #363 branch must be accessible
- Dispatcher must use `wo_routing_rules.yaml` (already verified)
- LPE routing must work (already verified)

---

## 10. Timeline

**Estimated Time:** 15-30 minutes

- Verification: 5 minutes
- Implementation: 5 minutes
- Testing: 10 minutes
- PR update: 5 minutes

---

**Generated by:** Andy (Codex Layer 4) following `/feature-dev` pattern  
**Review Status:** Ready for implementation  
**Plan Date:** 2025-11-18
