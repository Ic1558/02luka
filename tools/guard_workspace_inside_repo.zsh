#!/usr/bin/env zsh
set -euo pipefail

# Guard: Prevent workspace directories from existing as real dirs in repo
# Run this before commits/PRs to catch accidental workspace creation

REPO="${HOME}/02luka"

if [[ ! -d "$REPO/.git" ]]; then
  echo "ERROR: $REPO is not a git repo" >&2
  exit 1
fi

cd "$REPO"

# Workspace paths that MUST be symlinks (never real directories)
workspace_paths=(
  "g/data"
  "g/telemetry"
  "g/followup"
  "mls/ledger"
  "bridge/processed"
)

# Secrets/env files that MUST be symlinks (never real files in repo)
env_files=(
  ".env.local"
)

failed=0

echo "== Guard: Checking workspace paths are symlinks =="
for path in "${workspace_paths[@]}"; do
  full_path="$REPO/$path"
  
  # If path doesn't exist at all, that's ok (might not be created yet)
  if [[ ! -e "$full_path" ]]; then
    continue
  fi
  
  # If path exists but is NOT a symlink -> FAIL
  if [[ ! -L "$full_path" ]]; then
    echo "❌ FAIL: $path exists as real directory (must be symlink to workspace)" >&2
    if [[ -d "$full_path" ]]; then
      echo "   Found: real directory" >&2
    elif [[ -f "$full_path" ]]; then
      echo "   Found: real file" >&2
    else
      echo "   Found: other type (not symlink)" >&2
    fi
    echo "   Fix: Run bootstrap_workspace.zsh or manually migrate to ~/02luka_ws/" >&2
    failed=1
  else
    # Verify it's a symlink (critical check)
    echo "✓ OK: $path is symlink (as required)"
  fi
done

echo ""
echo "== Guard: Checking .env.local (must be symlink if exists) =="
for env_file in "${env_files[@]}"; do
  full_path="$REPO/$env_file"
  
  if [[ ! -e "$full_path" ]]; then
    continue  # File doesn't exist, that's ok
  fi
  
  if [[ -f "$full_path" ]] && [[ ! -L "$full_path" ]]; then
    echo "❌ FAIL: $env_file exists as real file (must be symlink to workspace)" >&2
    echo "   Fix: Run bootstrap_workspace.zsh or:" >&2
    echo "        mkdir -p ~/02luka_ws/env" >&2
    echo "        mv $env_file ~/02luka_ws/env/$env_file" >&2
    echo "        ln -sfn ~/02luka_ws/env/$env_file $env_file" >&2
    failed=1
  elif [[ -L "$full_path" ]]; then
    echo "✓ OK: $env_file is symlink (as required)"
  fi
done

echo "== Guard: Checking workspace paths (if tracked, must be symlinks) =="
for path in "${workspace_paths[@]}"; do
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    # Path is tracked - verify it's a symlink (not real dir/file)
    full_path="$REPO/$path"
    if [[ -L "$full_path" ]]; then
      echo "✓ OK: $path is tracked as symlink (allowed)"
    else
      echo "❌ FAIL: git is tracking '$path' but it's a real dir/file (must be symlink)" >&2
      echo "   Fix: Remove from git, then create symlink: git rm --cached $path && zsh tools/bootstrap_workspace.zsh" >&2
      failed=1
    fi
  else
    # Not tracked - that's fine, but if it exists, must be symlink
    full_path="$REPO/$path"
    if [[ -e "$full_path" ]] && [[ ! -L "$full_path" ]]; then
      echo "❌ FAIL: $path exists as real dir/file but not tracked (should be symlink)" >&2
      echo "   Fix: Run bootstrap_workspace.zsh or create symlink manually" >&2
      failed=1
    else
      echo "✓ OK: $path not tracked (or is symlink)"
    fi
  fi
done

echo ""
if [[ "$failed" -eq 0 ]]; then
  echo "✅ All workspace guards passed"
  exit 0
else
  echo "❌ Workspace guard checks failed (see errors above)" >&2
  exit 1
fi
