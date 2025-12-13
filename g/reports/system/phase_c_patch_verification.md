# ADR-001: Repository/Workspace Split Architecture

**Status:** Accepted  
**Date:** 2025-12-13  
**Context:** Phase A Complete

---

## Context

The 02luka system needs to separate:
- **Repository (Git-tracked):** Source code, scripts, documentation
- **Workspace (Runtime data):** Telemetry, logs, followup data, MLS ledger

**Problem:** Git operations (`git clean -fd`, `git reset --hard`) were destroying runtime data stored in the repository.

---

## Decision

**Separate repository from workspace using symlinks:**

1. **Repository:** `/Users/icmini/02luka` (Git-tracked)
2. **Workspace:** `/Users/icmini/02luka_ws` (NOT in Git, external directory)
3. **Symlinks:** Workspace paths in repo are symlinks pointing to workspace

**Workspace paths (must be symlinks):**
- `g/data/` → `~/02luka_ws/g/data/`
- `g/telemetry/` → `~/02luka_ws/g/telemetry/`
- `g/followup/` → `~/02luka_ws/g/followup/`
- `mls/ledger/` → `~/02luka_ws/mls/ledger/`
- `bridge/processed/` → `~/02luka_ws/bridge/processed/`
- `g/apps/dashboard/data/followup.json` → `~/02luka_ws/g/apps/dashboard/data/followup.json`

---

## Consequences

### ✅ Benefits

- **Data Safety:** `git clean -fd` and `git reset --hard` won't delete workspace data
- **Git Hygiene:** Repository stays clean (no runtime data tracked)
- **Separation of Concerns:** Code vs. data clearly separated
- **Backup Strategy:** Workspace can be backed up independently

### ⚠️ Requirements

- **Pre-commit Hook:** Enforces workspace paths are symlinks (not real directories)
- **Guard Script:** `tools/guard_workspace_inside_repo.zsh` validates before commits
- **Safe Clean:** Use `tools/safe_git_clean.zsh` instead of `git clean -fd`
- **Bootstrap:** Run `tools/bootstrap_workspace.zsh` to setup symlinks

### 🚫 Prohibited Operations

- **NEVER:** `git clean -fd` (use `safe_git_clean.zsh` instead)
- **NEVER:** Create real directories at workspace paths (must be symlinks)
- **NEVER:** Track workspace data in Git (already in `.gitignore`)

---

## Implementation

**Phase A (Complete):**
- ✅ Guard script (`tools/guard_workspace_inside_repo.zsh`)
- ✅ Pre-commit hook (enforces guard)
- ✅ Bootstrap script (`tools/bootstrap_workspace.zsh`)
- ✅ Safe clean script (`tools/safe_git_clean.zsh`)
- ✅ All workspace paths migrated to symlinks

**Phase B (Recommended):**
- CI check for workspace guard
- Documentation updates
- Alias for safe clean

---

## References

- `.cursorrules` - Workspace split rules
- `tools/guard_workspace_inside_repo.zsh` - Guard implementation
- `tools/bootstrap_workspace.zsh` - Setup script
- `tools/safe_git_clean.zsh` - Safe clean wrapper

---

**Tag:** `ws-split-phase-a-ok` (2025-12-13)
#!/usr/bin/env zsh
set -euo pipefail

REPO=~/02luka
WS=~/02luka_ws
LOCAL=~/02luka_local

migrate_to_workspace() {
  local path="$1"
  local target="$2"
  echo "Migrating $path to workspace $target"
  mkdir -p "$(dirname "$target")"
  if [ -e "$path" ]; then
    mv "$path" "$target"
  fi
  ln -sfn "$target" "$path"
}

link_to() {
  local path="$1"
  local target="$2"
  echo "Linking $path to $target"
  ln -sfn "$target" "$path"
}

# Guard: check workspace paths are symlinks
guard_workspace_paths() {
  local paths=(
    "g/data"
    "g/telemetry"
    "g/followup"
    "mls/ledger"
    "bridge/processed"
    "g/apps/dashboard/data/followup.json"
  )
  local failed=0
  for p in "${paths[@]}"; do
    if [ ! -L "$p" ]; then
      echo "Workspace path $p is not a symlink."
      failed=1
    fi
  done
  return $failed
}

# Bootstrap workspace symlinks
bootstrap_workspace() {
  migrate_to_workspace "g/data" "$WS/g/data"
  migrate_to_workspace "g/telemetry" "$WS/g/telemetry"
  migrate_to_workspace "g/followup" "$WS/g/followup"
  migrate_to_workspace "mls/ledger" "$WS/mls/ledger"
  migrate_to_workspace "bridge/processed" "$WS/bridge/processed"
  migrate_to_workspace "g/apps/dashboard/data/followup.json" "$WS/g/apps/dashboard/data/followup.json"
}

if [[ "${1:-}" == "bootstrap" ]]; then
  bootstrap_workspace
  exit 0
fi

if ! guard_workspace_paths; then
  echo "Workspace guard failed. Please fix symlinks."
  exit 1
fi

# Phase C Patch Verification
**Date:** 2025-12-13  
**Status:** ✅ Patches Applied

---

## ✅ Patch Verification

### 1. `readlink_safe()` Function
**Location:** Lines 11-27  
**Status:** ✅ Present

```zsh
readlink_safe() {
  local p="$1"
  if [[ -x /usr/bin/readlink ]]; then
    /usr/bin/readlink "$p" && return 0
  fi
  # Fallback: python3
  python3 - <<'PY'
import os,sys
p=sys.argv[1]
try:
    print(os.readlink(p))
except OSError:
    sys.exit(1)
PY
  "$p"
}
```

**Usage:** All `readlink` calls replaced with `readlink_safe`:
- Line 57: `backup_target=$(readlink_safe g/data)`
- Line 97: `backups["$path"]=$(readlink_safe "$path")`
- Line 130: `target=$(readlink_safe "$path")`

### 2. Test 2: Improved Commit Check
**Location:** Lines 64-78  
**Status:** ✅ Present

**Changes:**
- Uses `set +e` / `set -e` to capture exit code
- Stores commit output to `/tmp/phase_c_test2_commit.log`
- Checks both exit code (`commit_rc -ne 0`) AND log content
- Better error message with log file path

**Before:**
```zsh
if git add test_violation/ 2>/dev/null && git commit -m "test violation" 2>&1 | grep -q "FAIL\|must be symlink"; then
```

**After:**
```zsh
tmp_out="/tmp/phase_c_test2_commit.log"
set +e
git add g/data/ >/dev/null 2>&1
git commit -m "test violation" >"$tmp_out" 2>&1
commit_rc=$?
set -e

if [[ $commit_rc -ne 0 ]] && grep -Eq "FAIL|must be symlink|real directory|Workspace guard checks failed" "$tmp_out"; then
```

---

## 🎯 Expected Behavior

### Test 2 Should:
1. Replace `g/data` symlink with real directory
2. Try to commit
3. Pre-commit hook should block (exit code != 0)
4. Log file should contain "FAIL" or "Workspace guard checks failed"
5. Test should PASS

### If Test 2 Fails:
Check log file:
```bash
cat /tmp/phase_c_test2_commit.log
```

**Possible issues:**
- Pre-commit hook not running
- Guard script not detecting violation
- Exit code check too strict

---

## 📋 Next Steps

1. **Run tests in clean terminal:**
   ```bash
   cd ~/02luka
   zsh tools/phase_c_execute.zsh
   ```

2. **If Test 2 fails:**
   ```bash
   cat /tmp/phase_c_test2_commit.log
   ```

3. **Verify pre-commit hook:**
   ```bash
   cat .git/hooks/pre-commit
   # Should show: exec zsh tools/guard_workspace_inside_repo.zsh
   ```

---

**Status:** Patches verified, ready for execution in clean terminal
#!/usr/bin/env zsh
set -euo pipefail

# Ensure a sane PATH even in constrained shells (Cursor/launchd/etc.)
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# --- helpers (PATH-safe core utils)
rm_safe() { /bin/rm "$@"; }
mkdir_safe() { /bin/mkdir "$@"; }
ln_safe() { /bin/ln "$@"; }
grep_safe() { /usr/bin/grep "$@"; }
cat_safe() { /bin/cat "$@"; }

readlink_safe() {
  local p="$1"
  if [[ -x /usr/bin/readlink ]]; then
    /usr/bin/readlink "$p" && return 0
  fi
  # Fallback: python3 (pass the path as argv)
  /usr/bin/python3 - "$p" <<'PY'
import os,sys
p=sys.argv[1]
try:
    print(os.readlink(p))
except OSError:
    sys.exit(1)
PY
}

echo "=== Phase C Patch Verification ==="

# Test 1: Check that g/data is a symlink
echo "Test 1: g/data symlink check"
if [[ ! -L g/data ]]; then
  echo "FAIL: g/data is not a symlink"
  exit 1
fi
echo "PASS: g/data is a symlink"

# Backup target of g/data
backup_target=$(readlink_safe g/data)

# Test 2: Commit should fail if g/data is a real directory
echo "Test 2: commit block on real directory"
rm_safe -f g/data
mkdir_safe -p g/data
tmp_out="/tmp/phase_c_test2_commit.log"
set +e
git add g/data/ >/dev/null 2>&1
git commit -m "test violation" >"$tmp_out" 2>&1
commit_rc=$?
set -e

if [[ $commit_rc -ne 0 ]] && grep_safe -Eq "FAIL|must be symlink|real directory|Workspace guard checks failed" "$tmp_out"; then
  echo "PASS: commit blocked as expected"
else
  echo "FAIL: commit was not blocked"
  cat_safe "$tmp_out"
  exit 1
fi

# Test 3: Workspace guard on all workspace paths
echo "Test 3: workspace guard on all paths"
declare -A backups
paths=(
  "g/data"
  "g/telemetry"
  "g/followup"
  "mls/ledger"
  "bridge/processed"
)

for path in "${paths[@]}"; do
  backups["$path"]="$(readlink_safe "$path")"
  echo "Testing path: $path"
  rm_safe -f "$path"
  mkdir_safe -p "$path"
  if tools/guard_workspace_inside_repo.zsh | grep_safe -q "FAIL\|real directory"; then
    echo "PASS: guard detected real directory for $path"
  else
    echo "FAIL: guard did not detect real directory for $path"
    exit 1
  fi
  rm_safe -rf "$path"
  ln_safe -sfn "${backups[$path]}" "$path"
done

if tools/guard_workspace_inside_repo.zsh | grep_safe -q "All workspace guards passed"; then
  echo "PASS: all workspace guards passed"
else
  echo "FAIL: workspace guards did not pass"
  exit 1
fi

# Test 4: Cleanup and final checks
echo "Test 4: cleanup and final checks"
rm_safe -f g/data g/telemetry g/followup mls/ledger bridge/processed 2>/dev/null || true
if tools/guard_workspace_inside_repo.zsh | grep_safe -q "FAIL"; then
  echo "PASS: guard detects missing symlinks"
else
  echo "FAIL: guard did not detect missing symlinks"
  cat_safe /tmp/phase_c_test4.log
  exit 1
fi

echo "All tests passed."
exit 0
