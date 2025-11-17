# PR #363 Code Review: LPE Worker Routing Rule Issue

**Date:** 2025-11-18  
**PR:** [#363 - feat(lpe): wire Local Patch Engine worker into WO pipeline](https://github.com/Ic1558/02luka/pull/363)  
**Status:** OPEN, MERGEABLE, All CI checks passing

---

## Executive Summary

**Verdict:** ⚠️ **BLOCKING ISSUE** — Routing rule mismatch prevents LPE routing from working

**Critical Finding:**
- Code review P1 Badge identifies routing rule field mismatch
- Routing rule uses `fallback: "lpe"` at top level
- Dispatcher and worker expect `task.fallback: "lpe"` (nested)
- **Impact:** Write jobs requesting LPE will NOT be routed correctly

**Status:**
- ✅ All CI checks passing
- ✅ Merge conflicts resolved
- ⚠️ **Routing rule needs fix before merge**

---

## Issue Analysis

### Code Review Feedback

**Source:** [chatgpt-codex-connector bot review](https://github.com/Ic1558/02luka/pull/363#discussion_r)

**P1 Badge: Align LPE routing rule with task.fallback field**

**Problem Identified:**

PR #363 adds a NEW file `g/config/orchestrator/routing_rules.yaml` with format:
```yaml
rules:
  - name: write-to-lpe
    when:
      task.type: "write"
      fallback: "lpe"    # ❌ Wrong format and field path
    route: "LPE"
```

**However:**
1. The dispatcher (`tools/watchers/mary_dispatcher.zsh`) reads from `g/config/wo_routing_rules.yaml` (NOT the new file)
2. The dispatcher expects format:
   ```yaml
   routes:
     - name: lpe-write-fallback
       match:
         task_type: write        # ✅ Uses task_type (not task.type)
         fallback_contains: lpe  # ✅ Uses fallback_contains (not fallback)
       target: LPE               # ✅ Uses target (not route)
   ```
3. Work orders use `route_hints.fallback_order: [lpe, clc]` (array), not `task.fallback`

**Impact:**
- The new routing rules file is **not used** by the dispatcher
- The dispatcher already has correct routing rule in `wo_routing_rules.yaml`
- The new file format doesn't match dispatcher expectations
- **Either:** Update dispatcher to read new file, **OR:** Remove new file and use existing one

---

## Current Implementation

### Routing Rule (PR Branch)
**File:** `g/config/orchestrator/routing_rules.yaml`

```yaml
rules:
  - name: write-to-lpe
    when:
      task.type: "write"
      fallback: "lpe"    # ❌ Wrong: top-level
    route: "LPE"
```

### Dispatcher Code
**File:** `tools/watchers/mary_dispatcher.zsh`

Expected structure:
```bash
task.fallback  # Nested under task object
```

### Worker Code
**File:** `g/tools/lpe_worker.zsh`

Expected structure:
```bash
task.fallback  # Nested under task object
```

---

## Required Fix

### Solution: Remove Unused File

**Issue:** PR #363 adds `g/config/orchestrator/routing_rules.yaml` which:
- Is NOT used by the dispatcher
- Has wrong format (doesn't match dispatcher expectations)
- Is redundant (correct rule already exists in `wo_routing_rules.yaml`)

**Fix:** Remove the new file since routing already works correctly.

**File to Remove:** `g/config/orchestrator/routing_rules.yaml`

**Reason:**
1. Dispatcher reads from `g/config/wo_routing_rules.yaml` (already has correct LPE rule)
2. Dispatcher was updated in PR #363 to handle LPE routing (converts YAML to JSON)
3. The new file format doesn't match dispatcher expectations
4. Routing works correctly with existing `wo_routing_rules.yaml`

### Alternative: Fix File Format (if file is needed)

If the new file is intended for future use, it should match dispatcher format:

**Current (wrong):**
```yaml
rules:
  - name: write-to-lpe
    when:
      task.type: "write"
      fallback: "lpe"
    route: "LPE"
```

**Should be (if used):**
```yaml
routes:
  - name: write-to-lpe
    match:
      task_type: write
      fallback_contains: lpe
    target: LPE
```

**But:** Since dispatcher already has correct rule, removing the file is simpler.

### Verification

After fix, verify:
1. Dispatcher routes LPE work orders correctly (already working)
2. Worker receives work orders with `route_hints.fallback_order: [lpe, clc]`
3. Smoke test passes
4. No unused config files remain

---

## Testing

### Smoke Test
**File:** `g/tools/lpe_smoke_test.zsh`

Should test:
- Work order with `task.fallback: "lpe"` structure
- Routing to LPE queue
- Worker processing

### Manual Test
1. Create test WO with `task.fallback: "lpe"`
2. Verify routing rule matches
3. Verify dispatcher routes to LPE
4. Verify worker processes WO

---

## Risk Assessment

### High Risk
- **Routing Rule Mismatch** — Blocks all LPE routing functionality
- **Impact:** Feature doesn't work as intended

### Medium Risk
- **Testing** — Need to verify fix works end-to-end

### Low Risk
- **Fix Complexity** — Simple field path change

---

## Recommendations

### Immediate Action
1. **Remove unused file** — Delete `g/config/orchestrator/routing_rules.yaml`
2. **Verify routing works** — Confirm dispatcher uses `wo_routing_rules.yaml` correctly
3. **Update PR** — Remove unused file commit

### Before Merge
- [ ] Remove `g/config/orchestrator/routing_rules.yaml` (unused, wrong format)
- [ ] Verify routing works with existing `wo_routing_rules.yaml`
- [ ] Run smoke test
- [ ] Verify end-to-end routing
- [ ] Update PR description to clarify routing uses existing file

---

## Current PR Status

**Status:** OPEN, MERGEABLE  
**CI Checks:** ✅ All passing (23 checks)  
**Merge State:** CLEAN  
**Readiness Score:** 74.5/100

**Files Changed:**
- `g/config/orchestrator/routing_rules.yaml` (+12 lines)
- `tools/watchers/mary_dispatcher.zsh` (+52, -10 lines)

---

## Next Steps

1. ⚠️ **Fix routing rule** (blocking issue)
2. ⏳ Test routing functionality
3. ⏳ Update PR with fix
4. ⏳ Re-run CI checks
5. ⏳ Ready for merge

---

## References

- PR #363: https://github.com/Ic1558/02luka/pull/363
- Code Review Comment: P1 Badge - Align LPE routing rule
- Routing Rules: `g/config/orchestrator/routing_rules.yaml`
- Dispatcher: `tools/watchers/mary_dispatcher.zsh`
- Worker: `g/tools/lpe_worker.zsh`

---

## Classification

```yaml
classification:
  task_type: PR_REVIEW
  primary_tool: codex_cli
  needs_pr: true
  security_sensitive: false
  reason: "Code review of PR #363 LPE worker routing - identifies blocking routing rule mismatch"
```
