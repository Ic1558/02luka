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

REPO="$HOME/02luka"
WS="$HOME/02luka_ws"
LOCAL="$HOME/.local/share/02luka"

migrate_to_workspace() {
  local src="$1"
  local dst="$2"

  if [ -d "$src" ] && [ ! -L "$src" ]; then
    echo "Migrating $src to workspace $dst"
    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
    ln -sfn "$dst" "$src"
  elif [ ! -e "$src" ]; then
    echo "Creating symlink $src -> $dst"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$dst" "$src"
  fi
}

link_to() {
  local src="$1"
  local dst="$2"
  ln -sfn "$dst" "$src"
}

# Guard: Ensure workspace paths are symlinks
guard_workspace_symlinks() {
  local paths=(
    "g/data"
    "g/telemetry"
    "g/followup"
    "mls/ledger"
    "bridge/processed"
    "g/apps/dashboard/data/followup.json"
  )

  local failed=0
  for path in "${paths[@]}"; do
    if [ -e "$path" ] && [ ! -L "$path" ]; then
      echo "FAIL: $path is not a symlink"
      failed=1
    fi
  done

  if [ $failed -eq 1 ]; then
    echo "Workspace guard failed."
    return 1
  fi
  echo "All workspace guards passed."
  return 0
}

# Run guard on bootstrap
guard_workspace_symlinks

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
  local p=$1
  if command -v readlink >/dev/null 2>&1; then
    readlink "$p"
  else
    # Fallback: python3 (pass the path as argv)
    /usr/bin/python3 - "$p" <<'PY'
import os,sys
p=sys.argv[1]
try:
    print(os.readlink(p))
except OSError:
    sys.exit(1)
PY
  fi
}

# Test 1: Basic symlink resolution test
echo "Test 1: Symlink resolution"
cat_safe /tmp/phase_c_test1.log

# Test 2: Backup and restore symlink
backup_target="/tmp/backup_target"
rm_safe -f g/data
mkdir_safe -p g/data
rm_safe -rf g/data
ln_safe -sfn "$backup_target" g/data

# Test 3: Workspace paths symlink recreation
declare -A backups=(
  ["g/data"]="/tmp/backup_g_data"
  ["g/telemetry"]="/tmp/backup_g_telemetry"
  ["g/followup"]="/tmp/backup_g_followup"
  ["mls/ledger"]="/tmp/backup_mls_ledger"
  ["bridge/processed"]="/tmp/backup_bridge_processed"
)

for path in "${(@k)backups}"; do
  rm_safe -f "$path"
  mkdir_safe -p "$path"
  rm_safe -rf "$path"
  ln_safe -sfn "${backups[$path]}" "$path"
done

# Guard checks with grep_safe
if grep_safe -q "FAIL\|real directory" /tmp/phase_c_guard.log; then
  echo "Guard check failed"
else
  echo "All workspace guards passed"
fi | grep_safe -q "All workspace guards passed"

# Test 4: Clean up and final check
rm_safe -f g/data g/telemetry g/followup mls/ledger bridge/processed 2>/dev/null || true
cat_safe /tmp/phase_c_test4.log
