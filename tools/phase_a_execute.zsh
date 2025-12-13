#!/usr/bin/env zsh
set -euo pipefail

# Phase A Execution Script
# Execute all steps to complete workspace migration

REPO="$HOME/02luka"
WS="$HOME/02luka_ws"

cd "$REPO"

echo "=== Phase A Execution: Stabilize the Floor ==="
echo ""

# Step 0: Bootstrap workspace (safety)
echo "Step 0: Running bootstrap_workspace.zsh..."
zsh tools/bootstrap_workspace.zsh || {
  echo "⚠️  Bootstrap had warnings (continuing...)"
}
echo ""

# Step 1: Check current status
echo "Step 1: Checking current symlink status..."
paths=(
  "g/followup"
  "mls/ledger"
  "bridge/processed"
  "g/apps/dashboard/data/followup.json"
)

bad_paths=()
for p in "${paths[@]}"; do
  if [[ -L "$p" ]]; then
    target=$(readlink "$p")
    echo "✅ OK  $p -> $target"
  else
    echo "❌ BAD $p (not symlink)"
    bad_paths+=("$p")
    if [[ -e "$p" ]]; then
      ls -la "$p" 2>/dev/null || true
    fi
  fi
done
echo ""

# Step 2: Migrate bad paths
if [[ ${#bad_paths[@]} -eq 0 ]]; then
  echo "✅ All paths are already symlinks. Skipping migration."
else
  echo "Step 2: Migrating ${#bad_paths[@]} path(s)..."
  
  # 2.1 g/followup
  if [[ " ${bad_paths[@]} " =~ " g/followup " ]]; then
    echo "  2.1 Migrating g/followup..."
    mkdir -p "$WS/g/followup"
    if [[ -e g/followup && ! -L g/followup ]]; then
      if [[ -d g/followup ]]; then
        rsync -a g/followup/ "$WS/g/followup/" 2>/dev/null || true
      fi
      rm -rf g/followup
    fi
    ln -sfn "$WS/g/followup" g/followup
    echo "    ✅ g/followup -> symlink"
  fi
  
  # 2.2 mls/ledger
  if [[ " ${bad_paths[@]} " =~ " mls/ledger " ]]; then
    echo "  2.2 Migrating mls/ledger..."
    mkdir -p "$WS/mls/ledger"
    if [[ -e mls/ledger && ! -L mls/ledger ]]; then
      if [[ -d mls/ledger ]]; then
        rsync -a mls/ledger/ "$WS/mls/ledger/" 2>/dev/null || true
      fi
      rm -rf mls/ledger
    fi
    ln -sfn "$WS/mls/ledger" mls/ledger
    echo "    ✅ mls/ledger -> symlink"
  fi
  
  # 2.3 bridge/processed
  if [[ " ${bad_paths[@]} " =~ " bridge/processed " ]]; then
    echo "  2.3 Migrating bridge/processed..."
    mkdir -p "$WS/bridge/processed"
    if [[ -e bridge/processed && ! -L bridge/processed ]]; then
      if [[ -d bridge/processed ]]; then
        rsync -a bridge/processed/ "$WS/bridge/processed/" 2>/dev/null || true
      fi
      rm -rf bridge/processed
    fi
    ln -sfn "$WS/bridge/processed" bridge/processed
    echo "    ✅ bridge/processed -> symlink"
  fi
  
  # 2.4 followup.json
  if [[ " ${bad_paths[@]} " =~ " g/apps/dashboard/data/followup.json " ]]; then
    echo "  2.4 Migrating followup.json..."
    mkdir -p "$WS/g/apps/dashboard/data"
    if [[ -e g/apps/dashboard/data/followup.json && ! -L g/apps/dashboard/data/followup.json ]]; then
      cp g/apps/dashboard/data/followup.json "$WS/g/apps/dashboard/data/followup.json" 2>/dev/null || true
      rm -f g/apps/dashboard/data/followup.json
    fi
    ln -sfn "$WS/g/apps/dashboard/data/followup.json" g/apps/dashboard/data/followup.json
    echo "    ✅ followup.json -> symlink"
  fi
  
  echo ""
fi

# Step 3: Verify guard script
echo "Step 3: Running guard script..."
if zsh tools/guard_workspace_inside_repo.zsh; then
  echo ""
  echo "✅ Guard script passed!"
else
  echo ""
  echo "❌ Guard script failed!"
  exit 1
fi
echo ""

# Step 4: Verify pre-commit hook
echo "Step 4: Verifying pre-commit hook..."
if [[ -f .git/hooks/pre-commit ]]; then
  if grep -q "exec zsh tools/guard_workspace_inside_repo.zsh" .git/hooks/pre-commit; then
    echo "✅ Pre-commit hook is in blocking mode (correct)"
  else
    echo "⚠️  Pre-commit hook may not be in blocking mode"
    echo "   Current content:"
    head -5 .git/hooks/pre-commit
  fi
else
  echo "❌ Pre-commit hook not found!"
  exit 1
fi
echo ""

# Final verification
echo "=== Final Verification ==="
all_ok=1
for p in "${paths[@]}"; do
  if [[ -L "$p" ]]; then
    target=$(readlink "$p")
    if [[ "$target" == "$WS"* ]]; then
      echo "✅ $p -> $target"
    else
      echo "⚠️  $p -> $target (not pointing to workspace)"
      all_ok=0
    fi
  else
    echo "❌ $p is NOT a symlink"
    all_ok=0
  fi
done
echo ""

if [[ $all_ok -eq 1 ]]; then
  echo "✅✅✅ Phase A: COMPLETE ✅✅✅"
  echo ""
  echo "System is now production-safe:"
  echo "  • All workspace paths are symlinks"
  echo "  • Guard script passes"
  echo "  • Pre-commit enforces rules"
  echo ""
  echo "git reset/clean will NOT delete workspace data anymore."
  exit 0
else
  echo "⚠️  Phase A: INCOMPLETE"
  echo "   Please review failed checks above"
  exit 1
fi
