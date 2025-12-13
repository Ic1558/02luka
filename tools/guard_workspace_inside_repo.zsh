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
    echo "   Found: $(file "$full_path")" >&2
    echo "   Fix: Run bootstrap_workspace.zsh or manually migrate to ~/02luka_ws/" >&2
    failed=1
  else
    # Verify it's a symlink (critical check)
    echo "✓ OK: $path is symlink (as required)"
  fi
done

echo ""
echo "== Guard: Checking workspace paths are NOT tracked in git =="
for path in "${workspace_paths[@]}"; do
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    echo "❌ FAIL: git is tracking '$path' (should be ignored/symlink only)" >&2
    echo "   Fix: git rm -r --cached $path" >&2
    failed=1
  else
    echo "✓ OK: $path not tracked in git"
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
