# PR #363 Sandbox Check Analysis

**Date:** 2025-11-18  
**PR:** #363  
**Issue:** Sandbox check failed

---

## Summary

**Status:** ⚠️ Sandbox check failed, but **NOT related to PR #363 changes**

**Finding:** The sandbox failure is a false positive from comments in `tools/codex_sandbox_check.zsh`, not from PR #363 changes.

---

## Analysis

### PR #363 Changes

**Files Changed:**
1. `tools/watchers/mary_dispatcher.zsh` (+52, -10 lines)
2. `g/config/orchestrator/routing_rules.yaml` (removed)

### Sandbox Check Results

**Local Test:**
```bash
tools/codex_sandbox_check.zsh tools/watchers/mary_dispatcher.zsh
# Result: ✅ No violations in mary_dispatcher.zsh
```

**CI Sandbox Failure:**
- Failed check: `sandbox`
- Run: 19445696394
- Violations found: 2 (both false positives)

**False Positive Source:**
```
[superuser_exec] Inline privilege escalation → tools/codex_sandbox_check.zsh:138-139
# Comments mentioning "sudo" in the sandbox check script itself
```

### Root Cause

The sandbox check scans **all files** in the repository, not just changed files. The failure is from:
- Comments in `tools/codex_sandbox_check.zsh` that mention "sudo" (lines 138-139)
- These are comments explaining exemptions, not actual code
- The sandbox checker is detecting the word "sudo" in comments

**PR #363 Changes:**
- `mary_dispatcher.zsh` - ✅ No sandbox violations (verified locally)
- Removed routing file - ✅ No impact

---

## Verification

### Changed Files Check

**mary_dispatcher.zsh:**
- ✅ No `rm -rf` commands
- ✅ No `sudo` commands
- ✅ No `kill -9` commands
- ✅ Safe file operations (cp, mv, mkdir)
- ✅ No banned patterns detected

**Removed File:**
- ✅ No impact (file deleted)

---

## Recommendation

### Option 1: Ignore False Positive (Recommended)

**Reason:**
- PR #363 changes are sandbox-compliant
- Failure is from unrelated file (sandbox checker itself)
- All other CI checks passing (19/24 passed, 1 failed, 4 skipped)

**Action:**
- Proceed with merge (sandbox failure is false positive)
- Note in PR that sandbox failure is unrelated

### Option 2: Fix Sandbox Checker (Future)

**Action:**
- Update `tools/codex_sandbox_check.zsh` to exclude comments
- Or update comments to avoid triggering regex

**Priority:** Low (doesn't block PR #363)

---

## Current Status

**CI Checks:**
- ✅ Passed: 19 checks
- ❌ Failed: 1 check (sandbox - false positive)
- ⏭️ Skipped: 4 checks
- **Total:** 24 checks

**PR Status:**
- Mergeable: MERGEABLE
- Merge State: UNSTABLE (due to sandbox failure)
- Changes: Safe (no actual violations)

---

## Conclusion

**Verdict:** ✅ **PR #363 changes are safe** — Sandbox failure is false positive

**Recommendation:** Proceed with merge. The sandbox failure is from comments in the sandbox checker itself, not from PR #363 changes.

---

## References

- PR #363: https://github.com/Ic1558/02luka/pull/363
- Sandbox Run: https://github.com/Ic1558/02luka/actions/runs/19445696394
- Sandbox Checker: `tools/codex_sandbox_check.zsh`
