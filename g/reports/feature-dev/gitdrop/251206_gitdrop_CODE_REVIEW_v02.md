# GitDrop v02 Code Review

**Reviewer:** CLS (Cognitive Local System Orchestrator)  
**Date:** 2025-12-06  
**Documents Reviewed:**
- `251206_gitdrop_SPEC_v02.md` (Minimal Phase 1)
- `251206_gitdrop_PLAN_v02.md` (Implementation Plan)
- Previous review: `251206_gitdrop_CODE_REVIEW_v01.md`

**Status:** ⚠️ **APPROVED WITH CRITICAL FIXES REQUIRED**

---

## Executive Summary

**v02 Improvements:**
- ✅ **Reduced scope** (Phase 1 only) - Lower risk, faster implementation
- ✅ **Clearer migration path** (replaces, not coexists)
- ✅ **Better error handling** (graceful degradation)
- ✅ **Simpler architecture** (single file, stdlib only)

**Critical Issues Remaining:**
1. 🔴 **Path handling** - Still uses `~/02luka` (violates `.cursorrules`)
2. 🔴 **Sandbox compliance** - Hook example not verified
3. 🟡 **Error logging location** - Uses `~/02luka` in error message

**Recommendation:** ✅ **Proceed after fixing path issues** (5-minute fix)

---

## Style Check

### ✅ Strengths

1. **Consistent formatting** - Markdown structure is clean
2. **Clear scope boundaries** - "What's Included" vs "What's NOT Included" is explicit
3. **Good error messages** - User-friendly "desk metaphor" language
4. **Minimal dependencies** - Python stdlib only ✅

### ⚠️ Issues

1. **Path inconsistency** - Uses `~/02luka` instead of absolute paths
2. **Missing `set -euo pipefail`** - Hook example doesn't include safety flags
3. **No shebang verification** - Doesn't specify Python version requirement

---

## History-Aware Review (v01 → v02)

### ✅ Improvements

| Aspect | v01 | v02 | Impact |
|--------|-----|-----|--------|
| **Scope** | Full system (6-7h) | Phase 1 only (4-5h) | ✅ Lower risk |
| **Migration** | Coexist (unclear) | Replace (clear) | ✅ Simpler |
| **Error handling** | Basic | Graceful degradation | ✅ Better UX |
| **Features** | 10+ commands | 3 core commands | ✅ Focused |
| **Testing** | 2 hours | 1 hour | ✅ Faster validation |

### ⚠️ Regressions

| Issue | v01 Status | v02 Status | Impact |
|-------|------------|-----------|--------|
| **Path handling** | ❌ Identified | ❌ **Still present** | 🔴 High |
| **Sandbox compliance** | ❌ Identified | ❌ **Not addressed** | 🔴 High |
| **Error logging** | ✅ Recommended | ⚠️ Partial | 🟡 Medium |

---

## Obvious Bug Scan

### 🔴 CRITICAL BUGS

#### BUG-1: Path Expansion Failure Risk

**Location:** `251206_gitdrop_PLAN_v02.md` lines 92, 96

**Issue:**
```bash
python3 ~/02luka/tools/gitdrop.py backup \
  --reason "git checkout $@" \
  --quiet || {
  echo "[GitDrop] See: ~/02luka/_gitdrop/error.log"
}
```

**Problem:**
- `~/02luka` may not expand in hook context (non-interactive shell)
- `.cursorrules` mandates: "Always use absolute paths starting with `/Users/icmini/02luka`"
- Could cause silent failures

**Fix:**
```bash
#!/usr/bin/env zsh
# GitDrop Phase 1: Safety before checkout
set -euo pipefail

LUKA_SOT="/Users/icmini/02luka"
"$LUKA_SOT/tools/gitdrop.py" backup \
  --reason "git checkout $@" \
  --quiet || {
  echo "[GitDrop] ⚠️ Backup failed but continuing checkout" >&2
  echo "[GitDrop] See: $LUKA_SOT/_gitdrop/error.log" >&2
}

exit 0
```

**Impact:** 🔴 **HIGH** - Could cause hooks to fail silently

---

#### BUG-2: Sandbox Compliance Not Verified

**Location:** `251206_gitdrop_PLAN_v02.md` lines 88-101

**Issue:**
- Hook will be scanned by `tools/codex_sandbox_check.zsh`
- Current example is safe, but not explicitly verified
- No `# sandbox: ...` comments

**Fix:**
1. Verify hook doesn't contain disallowed patterns
2. Add comment if any exceptions needed:
   ```bash
   # sandbox: safe - no disallowed patterns, uses absolute paths
   ```

**Impact:** 🔴 **HIGH** - CI sandbox check will fail

---

### 🟡 MEDIUM PRIORITY ISSUES

#### BUG-3: Error Logging Path Inconsistency

**Location:** `251206_gitdrop_PLAN_v02.md` line 96

**Issue:**
```bash
echo "[GitDrop] See: ~/02luka/_gitdrop/error.log"
```

**Problem:**
- Uses `~/02luka` in error message (inconsistent with fix)
- Should use same variable as script path

**Fix:**
```bash
echo "[GitDrop] See: $LUKA_SOT/_gitdrop/error.log"
```

**Impact:** 🟡 **MEDIUM** - User experience

---

#### BUG-4: Missing `set -euo pipefail` in Hook

**Location:** `251206_gitdrop_PLAN_v02.md` line 89

**Issue:**
- Hook example doesn't include `set -euo pipefail`
- `.cursorrules` mandates: "Always include `set -euo pipefail` for safety"

**Fix:**
```bash
#!/usr/bin/env zsh
set -euo pipefail
# ... rest of hook
```

**Impact:** 🟡 **MEDIUM** - Safety best practice

---

#### BUG-5: Python Version Not Specified

**Location:** `251206_gitdrop_PLAN_v02.md` line 92

**Issue:**
- Uses `python3` but doesn't specify minimum version
- Should verify Python 3.6+ (for pathlib, f-strings if used)

**Recommendation:**
Add to PLAN:
```python
# Requires Python 3.6+ (for pathlib, f-strings)
import sys
if sys.version_info < (3, 6):
    sys.exit("GitDrop requires Python 3.6+")
```

**Impact:** 🟢 **LOW** - Edge case

---

## Risk Analysis

### 🔴 High Risk Areas

1. **Path Expansion Failure**
   - **Risk:** Hook fails silently, no backups created
   - **Mitigation:** Use absolute paths (5-minute fix)
   - **Probability:** Medium (depends on shell context)

2. **Sandbox Check Failure**
   - **Risk:** CI blocks PR, deployment delayed
   - **Mitigation:** Verify hook against `schemas/codex_disallowed_commands.yaml`
   - **Probability:** High (if not addressed)

3. **Disk Space Exhaustion**
   - **Risk:** Backup fills disk, system fails
   - **Mitigation:** Manual cleanup (Boss controls)
   - **Probability:** Low (Phase 1 scope is limited)

### 🟡 Medium Risk Areas

4. **Restore Conflicts**
   - **Risk:** User overwrites important files
   - **Mitigation:** Default to `.gitdrop-restored-<id>` suffix
   - **Probability:** Low (non-destructive by default)

5. **Hook Breaks Git Operations**
   - **Risk:** Checkout blocked or slow
   - **Mitigation:** Always `exit 0`, graceful degradation
   - **Probability:** Low (design prevents blocking)

---

## Diff Hotspots (Areas Requiring Careful Review)

### 1. Hook Implementation (`tools/gitdrop.py` + `.git/hooks/pre-checkout`)

**Why:** Critical path, affects every checkout operation

**Check:**
- ✅ Absolute paths used
- ✅ Error handling doesn't block Git
- ✅ Sandbox compliance verified
- ✅ Logging to correct location

### 2. File Scope Filtering (`backup()` function)

**Why:** Determines what gets backed up (performance + storage)

**Check:**
- ✅ Only critical files (`g/reports/**`, `tools/*.{zsh,py}`, `*.md`)
- ✅ Excludes large directories (`node_modules/`, `__pycache__/`)
- ✅ Handles edge cases (symlinks, permissions)

### 3. Restore Conflict Resolution (`restore_snapshot()`)

**Why:** Prevents data loss from overwrites

**Check:**
- ✅ Default non-destructive (suffix approach)
- ✅ `--overwrite` flag works correctly
- ✅ Logs all restore operations

### 4. Index Management (`index.jsonl`)

**Why:** Corruption could lose snapshot metadata

**Check:**
- ✅ Atomic writes (append-only)
- ✅ Handles corruption gracefully
- ✅ Can rebuild from snapshots (future: `rebuild-index` command)

---

## Comparison: v01 Review vs v02 Status

| Issue | v01 Review | v02 Status | Action |
|-------|------------|------------|--------|
| **CRIT-1: Path handling** | ❌ Identified | ❌ **Still present** | 🔴 **MUST FIX** |
| **CRIT-2: Sandbox compliance** | ❌ Identified | ❌ **Not addressed** | 🔴 **MUST FIX** |
| **CRIT-3: Error handling** | ⚠️ Missing | ✅ **Improved** | ✅ Fixed |
| **CRIT-4: Migration path** | ⚠️ Unclear | ✅ **Clarified** | ✅ Fixed |
| **HIGH-1: .gitignore entry** | ⚠️ Missing | ✅ **Included** | ✅ Fixed |
| **HIGH-2: Python path** | ⚠️ Hardcoded | ⚠️ **Still hardcoded** | 🟡 Should fix |
| **HIGH-3: Conflict resolution** | ⚠️ Unclear | ✅ **Defined** | ✅ Fixed |

---

## Recommendations

### Must Fix Before Implementation:

1. ✅ **Fix path handling** - Replace `~/02luka` with `/Users/icmini/02luka` in:
   - Hook example (PLAN line 92)
   - Error message (PLAN line 96)
   - SPEC hook example (SPEC line 287)

2. ✅ **Add `set -euo pipefail`** - Include in hook example

3. ✅ **Verify sandbox compliance** - Run `tools/codex_sandbox_check.zsh` on hook before committing

### Should Fix:

4. ✅ **Use consistent variable** - Define `LUKA_SOT` once, reuse everywhere

5. ✅ **Add Python version check** - Specify minimum version (3.6+)

### Nice to Have:

6. ✅ **Add hook backup step** - Document backing up current hook before replacement

---

## Updated Hook Example (Fixed)

```bash
#!/usr/bin/env zsh
# GitDrop Phase 1: Safety before checkout
set -euo pipefail

# sandbox: safe - no disallowed patterns, uses absolute paths
LUKA_SOT="/Users/icmini/02luka"

"$LUKA_SOT/tools/gitdrop.py" backup \
  --reason "git checkout $@" \
  --quiet || {
  echo "[GitDrop] ⚠️ Backup failed but continuing checkout" >&2
  echo "[GitDrop] See: $LUKA_SOT/_gitdrop/error.log" >&2
}

# Always allow checkout to proceed
exit 0
```

---

## Implementation Checklist (Updated)

### Pre-Implementation:

- [ ] Fix path handling in PLAN v02 (lines 92, 96)
- [ ] Fix path handling in SPEC v02 (line 287)
- [ ] Add `set -euo pipefail` to hook example
- [ ] Add sandbox compliance comment
- [ ] Verify hook against `codex_sandbox_check.zsh`

### Phase 1 Implementation:

- [ ] Create `tools/gitdrop.py` with absolute paths
- [ ] Implement `backup()` with scope filtering
- [ ] Implement `restore_snapshot()` with conflict handling
- [ ] Add CLI (`list`, `show`, `restore`)
- [ ] Update `.gitignore` (add `_gitdrop/`)
- [ ] Replace `.git/hooks/pre-checkout` (with fixed version)
- [ ] Test end-to-end workflow

### Post-Implementation:

- [ ] Run sandbox check: `tools/codex_sandbox_check.zsh`
- [ ] Test with real checkout operations
- [ ] Verify error handling (disk full, permissions)
- [ ] Document usage in `_gitdrop/README.md`

---

## Final Verdict

**Status:** ⚠️ **APPROVED WITH CONDITIONS**

**Conditions:**
1. **MUST FIX** path handling (5-minute change)
2. **MUST VERIFY** sandbox compliance before commit
3. **SHOULD ADD** `set -euo pipefail` for safety

**Timeline:** 4-5 hours estimate is **reasonable** (unchanged)

**Risk Level:** 🟢 **LOW** (after fixing path issues)

**Recommendation:** ✅ **Proceed with implementation** after applying fixes above

---

## Summary

**What Changed (v01 → v02):**
- ✅ Reduced scope (Phase 1 only)
- ✅ Clearer migration strategy
- ✅ Better error handling
- ❌ **Path issues still present** (must fix)

**Critical Path:**
1. Fix paths in PLAN/SPEC (5 min)
2. Implement `gitdrop.py` (4-5 hours)
3. Test & verify (1 hour)
4. Deploy & monitor (2 weeks evaluation)

**Blockers:** None (after path fix)

**Next Steps:**
1. Apply path fixes to PLAN/SPEC v02
2. Begin implementation
3. Verify sandbox compliance before PR

---

**Reviewer Notes:**
- v02 is a **significant improvement** over v01 (better scope, clearer path)
- Only **2 critical issues** remain (both 5-minute fixes)
- Ready for implementation **after path fixes**
- Phase 1 approach is **sound** - evaluate after 2 weeks before expanding
