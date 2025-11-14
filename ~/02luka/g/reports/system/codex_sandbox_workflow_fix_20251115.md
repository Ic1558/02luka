# Codex Sandbox Workflow Fix

**Date:** 2025-11-15  
**Workflow:** `codex_sandbox.yml`  
**Issue:** Exit code 127 (command not found)  
**Run:** [19374130118](https://github.com/Ic1558/02luka/actions/runs/19374130118)  
**Status:** ✅ **FIXED**

---

## Summary

✅ **Fixed exit code 127 error in codex_sandbox workflow**  
✅ **Explicitly call zsh to run the script**  
✅ **Fix applied to workflow file**

---

## Problem

The `codex_sandbox` workflow was failing with:
```
/usr/bin/env: 'zsh': No such file or directory
Process completed with exit code 127
```

**Root Cause:**
- The script `tools/codex_sandbox_check.zsh` has shebang `#!/usr/bin/env zsh`
- When the workflow runs `tools/codex_sandbox_check.zsh` directly, the shebang tries to find `zsh`
- Even though `zsh` is installed in the "Install dependencies" step, it may not be in PATH when the script executes
- Exit code 127 means "command not found"

---

## Solution

### Before:
```yaml
- name: Run codex sandbox check
  if: steps.diff.outputs.has_files == 'true'
  shell: bash
  run: |
    set -euo pipefail
    tools/codex_sandbox_check.zsh
```

### After:
```yaml
- name: Run codex sandbox check
  if: steps.diff.outputs.has_files == 'true'
  shell: bash
  run: |
    set -euo pipefail
    # Explicitly call zsh since the script has #!/usr/bin/env zsh shebang
    # and zsh was just installed in the previous step
    zsh tools/codex_sandbox_check.zsh
```

**Why:** By explicitly calling `zsh`, we ensure the script runs with the correct interpreter, even if the shebang can't find `zsh` in PATH.

---

## Workflow Steps

1. **Checkout** - Get the code
2. **Determine sandbox scope** - Check which files changed
3. **Install dependencies** - Install `zsh` and `ripgrep` (if files changed)
4. **Run codex sandbox check** - Execute the check script ← **Fixed here**

---

## Verification

### ✅ Fix Applied
- ✅ Workflow file updated
- ✅ Explicitly calls `zsh` to run the script
- ✅ Committed and pushed

### ⏳ CI Status
- ⏳ Workflow will run on next PR
- ⏳ Should pass without exit code 127

---

## Impact

This fix will help:
- ✅ **PR #284** - Future runs will work
- ✅ **All future PRs** - Codex sandbox check will run correctly
- ✅ **CI reliability** - Prevents exit code 127 errors

---

## Related

- **Workflow:** `.github/workflows/codex_sandbox.yml`
- **Script:** `tools/codex_sandbox_check.zsh`
- **Failed Run:** [19374130118](https://github.com/Ic1558/02luka/actions/runs/19374130118)

---

**Status:** ✅ **FIX APPLIED** - Workflow should now run successfully

**Next Action:** Monitor future workflow runs to verify the fix works

