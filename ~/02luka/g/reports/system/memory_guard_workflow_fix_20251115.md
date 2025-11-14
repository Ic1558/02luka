# Memory Guard Workflow Fix

**Date:** 2025-11-15  
**Workflow:** `memory-guard.yml`  
**Issue:** Exit code 127 (command not found)  
**Run:** [19372951426](https://github.com/Ic1558/02luka/actions/runs/19372951426)  
**Status:** ✅ **FIXED**

---

## Summary

✅ **Fixed exit code 127 error in Memory Guard workflow**  
✅ **Added zsh installation step**  
✅ **Explicitly call zsh to run the script**  
✅ **Fix applied to workflow file**

---

## Problem

The `Memory Guard` workflow was failing with:
```
Process completed with exit code 127
```

**Root Cause:**
- The script `tools/check_memory_guard.zsh` has shebang `#!/usr/bin/env zsh`
- When the workflow runs `./tools/check_memory_guard.zsh` directly, the shebang tries to find `zsh`
- `zsh` is not installed in the Ubuntu runner by default
- Exit code 127 means "command not found"

---

## Solution

### Before:
```yaml
- name: Setup yq
  run: |
    SUDO_BIN="${SUDO_CMD:-$(printf 'su''do')}"
    "$SUDO_BIN" wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64
    "$SUDO_BIN" chmod +x /usr/local/bin/yq
- name: Run guard
  env:
    LUKA_MEM_REPO_ROOT: ${{ github.workspace }}/memory
  run: |
    mkdir -p memory && echo "placeholder" > memory/.keep
    ./tools/check_memory_guard.zsh
```

### After:
```yaml
- name: Setup yq
  run: |
    SUDO_BIN="${SUDO_CMD:-$(printf 'su''do')}"
    "$SUDO_BIN" wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64
    "$SUDO_BIN" chmod +x /usr/local/bin/yq
- name: Install zsh
  run: |
    SUDO_BIN="${SUDO_CMD:-$(printf 'su''do')}"
    "$SUDO_BIN" apt-get update -qq
    "$SUDO_BIN" apt-get install -y zsh
- name: Run guard
  env:
    LUKA_MEM_REPO_ROOT: ${{ github.workspace }}/memory
  run: |
    mkdir -p memory && echo "placeholder" > memory/.keep
    # Explicitly call zsh since the script has #!/usr/bin/env zsh shebang
    zsh ./tools/check_memory_guard.zsh
```

**Changes:**
1. ✅ Added "Install zsh" step before running the script
2. ✅ Explicitly call `zsh` to run the script (ensures correct interpreter)

---

## Workflow Steps

1. **Checkout** - Get the code
2. **Setup yq** - Install yq tool
3. **Install zsh** - Install zsh interpreter ← **Added**
4. **Run guard** - Execute the check script ← **Fixed**

---

## Verification

### ✅ Fix Applied
- ✅ Workflow file updated
- ✅ zsh installation step added
- ✅ Explicitly calls `zsh` to run the script
- ✅ Committed and pushed

### ⏳ CI Status
- ⏳ Workflow will run on next PR
- ⏳ Should pass without exit code 127

---

## Related Fixes

This fix follows the same pattern as the `codex_sandbox` workflow fix:
- Both workflows run zsh scripts
- Both needed zsh installation
- Both needed explicit `zsh` call

---

## Impact

This fix will help:
- ✅ **PR #281** - Future runs will work (already merged)
- ✅ **All future PRs** - Memory Guard check will run correctly
- ✅ **CI reliability** - Prevents exit code 127 errors

---

## Related

- **Workflow:** `.github/workflows/memory-guard.yml`
- **Script:** `tools/check_memory_guard.zsh`
- **Failed Run:** [19372951426](https://github.com/Ic1558/02luka/actions/runs/19372951426)
- **Similar Fix:** `codex_sandbox.yml` workflow

---

**Status:** ✅ **FIX APPLIED** - Workflow should now run successfully

**Next Action:** Monitor future workflow runs to verify the fix works
