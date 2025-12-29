# Codex Findings - Action Plan
**Date:** 2025-12-30
**Source:** Codex test results from production validation
**Priority:** High (security + reliability improvements)

---

## Summary

During Codex Tier 2 testing, Codex identified **3 critical issues** in 02luka tools:

1. **High Severity:** `git add -A` in session_save.zsh (L480)
2. **Medium Severity:** Unescaped JSON in session_save.zsh (L51)
3. **Medium Severity:** Missing jq check in session_save.zsh (L171)

Plus: Error handling improvements applied to `mls_capture.zsh` (not tested yet).

**Status:** Issues identified, fixes proposed, **not yet applied**.

---

## Issue #1: Unsafe `git add -A` ✅ FIXED

**File:** `tools/session_save.zsh:480`
**Status:** ✅ **RESOLVED** (2025-12-30)
**Fixed by:** CLC
**Commit:** `d298b70e`

**Problem:**
```bash
git add -A  # Stages ALL changes in repo
git commit -m "session save: ..."
```

**Risk:**
- Accidentally commits unrelated files
- May commit sensitive data (.env, credentials)
- May commit work-in-progress code
- No validation of what's being committed

**Fix Applied:**
```bash
# Add only session-related files (explicit list for safety)
# Prevents accidentally committing unrelated or sensitive files
git add \
  g/reports/sessions/session_*.md \
  g/reports/sessions/session_*.ai.json \
  g/system_map/system_map.v1.json \
  02luka.md \
  2>/dev/null || true
```

**Validation:**
- ✅ Only expected session files committed
- ✅ Sensitive files protected (.env*, WIP code)
- ✅ Functionality preserved
- ✅ Safety comment added with reference

**Priority:** 🔴 High → ✅ **RESOLVED**
**Impact:** Security + reliability
**Time taken:** 10 min

---

## Issue #2: Unescaped JSON Fields (Medium Priority)

**File:** `tools/session_save.zsh:51`

**Problem:**
```bash
# Builds JSON with string interpolation
cat > metadata.json <<EOF
{
  "project": "$PROJECT_ID",
  "topic": "$SAVE_TOPIC",
  "agent": "$AGENT"
}
EOF
```

**Risk:**
- If PROJECT_ID contains quotes/newlines → invalid JSON
- JSON parsing errors downstream
- Silent failures

**Codex Suggestion:**
Use `jq -n` or proper escaping.

**Recommended Fix:**
```bash
# Safe: Use jq to build JSON
jq -n \
  --arg project "$PROJECT_ID" \
  --arg topic "$SAVE_TOPIC" \
  --arg agent "$AGENT" \
  '{
    project: $project,
    topic: $topic,
    agent: $agent
  }' > metadata.json
```

**Priority:** 🟡 Medium
**Impact:** Reliability
**Effort:** 15 min

---

## Issue #3: Missing jq Preflight Check ✅ FIXED

**File:** `tools/session_save.zsh:171`
**Status:** ✅ **RESOLVED** (2025-12-30)
**Fixed by:** Codex CLI (Tier 2 Interactive)
**Commit:** `611422ae`

**Problem:**
```bash
# Uses jq without checking if it exists
jq -r '.entries[]' ledger.jsonl | ...
# With set -e, missing jq = silent abort
```

**Risk:**
- Script fails mid-run if jq not installed
- No clear error message
- Confusing debugging

**Fix Applied:**
```bash
# Added at top of script (after set -euo pipefail)
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed"
  echo "Install: brew install jq"
  exit 1
fi
```

**Validation:**
- ✅ Preflight check at script start
- ✅ Clear error message if jq missing
- ✅ Actionable installation instruction
- ✅ Fail-fast behavior (exit 1)
- ✅ No regression in functionality

**Priority:** 🟡 Medium → ✅ **RESOLVED**
**Impact:** UX + reliability
**Time taken:** Interactive session (~5 min)
**Quality:** 9/10

---

## Issue #4: Error Handling in mls_capture.zsh (Not Tested)

**File:** `tools/mls_capture.zsh`

**Changes Made by Codex:**
1. ✅ Added jq availability checks
2. ✅ Type validation
3. ✅ Writable-path checks
4. ✅ JSON parsing backup on invalid index
5. ✅ Clearer failure messages

**Status:** ⚠️ **Not tested** (Codex stated "Tests not run (not requested)")

**Required Action:**
```bash
# Run tests to validate changes
zsh ~/02luka/tools/tests/mls_capture_test.zsh

# Or manual test
~/02luka/tools/mls_capture.zsh \
  --type solution \
  --producer test \
  --summary "Test entry" \
  --content "Test content"
```

**Priority:** 🟡 Medium
**Impact:** Validation needed
**Effort:** 15 min (testing)

---

## Implementation Plan

### Phase 1: Critical Fix (This Week)
**Priority:** Issue #1 (git add -A)

**Steps:**
1. Review current git add -A usage in session_save.zsh
2. Implement Option A or B (Boss choice)
3. Test with dry-run session save
4. Validate no unintended commits
5. Deploy

**Estimated time:** 30-45 min

---

### Phase 2: Reliability Fixes (Next Week)
**Priority:** Issues #2 + #3

**Steps:**
1. Replace string interpolation with jq -n (Issue #2)
2. Add jq preflight check (Issue #3)
3. Test session_save.zsh end-to-end
4. Validate JSON output correctness
5. Deploy

**Estimated time:** 30 min

---

### Phase 3: Validation (Next Week)
**Priority:** Issue #4 (mls_capture changes)

**Steps:**
1. Run mls_capture tests
2. Fix any issues found
3. Validate error handling works
4. Document changes
5. Deploy

**Estimated time:** 20 min

---

## Boss Decision Points

### Decision 1: Fix Approach for Issue #1

**Option A: Explicit file list (recommended)**
- ✅ Most secure (only expected files)
- ✅ Predictable behavior
- ⚠️ Less flexible (must update list if new files)

**Option B: Allowlist pattern check**
- ✅ Flexible (patterns match multiple files)
- ⚠️ Slightly more complex
- ⚠️ Pattern mistakes could miss files

**Recommendation:** Option A for session_save.zsh (small, known set of files)

---

### Decision 2: Timing

**Option 1: Fix now (this session)**
- ✅ Issues resolved immediately
- ✅ System safer before routing to Codex
- ⚠️ Extends current session

**Option 2: Fix in separate session**
- ✅ Current phase cleanly closed
- ✅ Fresh focus on fixes
- ⚠️ Issues remain until fixed

**Recommendation:** Option 2 (close Phase, fix in Week 1 tasks)

---

### Decision 3: Who Fixes?

**Option A: CLC fixes (Boss delegates to me)**
- ✅ Privileged zone (tools/)
- ✅ High confidence
- ⚠️ Uses CLC quota

**Option B: Codex fixes (route to Codex)**
- ✅ Saves CLC quota
- ✅ Tests Codex reliability
- ⚠️ First production fix task

**Option C: Boss fixes manually**
- ✅ Full control
- ⚠️ Takes Boss time

**Recommendation:** Option B (route to Codex) → validates Tier 2 setup with real task!

---

## Testing Checklist

### After Fix #1 (git add -A)
- [ ] Dry-run: `git status --porcelain` before commit
- [ ] Verify: Only expected files staged
- [ ] Test: Run session_save.zsh
- [ ] Validate: `git diff --cached` shows correct files

### After Fix #2 (JSON escaping)
- [ ] Test with PROJECT_ID containing quotes
- [ ] Test with SAVE_TOPIC containing newlines
- [ ] Validate: `jq . metadata.json` parses correctly
- [ ] Check: No escaped quotes in output

### After Fix #3 (jq check)
- [ ] Test without jq installed (uninstall temporarily)
- [ ] Verify: Clear error message shown
- [ ] Test with jq installed
- [ ] Verify: Script runs normally

### After Fix #4 (mls_capture)
- [ ] Run: `tools/tests/mls_capture_test.zsh`
- [ ] Test: Invalid index file handling
- [ ] Test: Missing jq handling
- [ ] Validate: Error messages clear

---

## Metrics

**Issues identified:** 4
**High severity:** 1
**Medium severity:** 3
**Estimated fix time:** 90-120 min total
**Impact:** Security + reliability + UX

**Success criteria:**
- All 4 issues fixed
- All tests passing
- No regressions
- Codex findings validated

---

## Next Steps (Recommended)

**Immediate (Today):**
1. ✅ Close current phase (Tier 2 complete)
2. ✅ Document findings (this file)
3. ✅ Plan Week 1 routing

**Week 1 (Starting Tomorrow):**
1. Route first real task to Codex: "Fix Issue #1 (git add -A)"
2. Validate Codex can apply fixes correctly
3. Test and deploy fixes
4. Continue routing 10-20 tasks to Codex

**This tests everything:**
- Tier 2 config works
- Codex can fix real issues
- Routing flow validated
- Metrics logging tested

---

**File:** `g/reports/feature-dev/codex_enhancement/CODEX_FINDINGS_ACTION_PLAN.md`
**Status:** Ready for Boss decision on timing + approach
**Recommendation:** Route Issue #1 fix to Codex as first production task (validates entire setup)
