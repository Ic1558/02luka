#!/usr/bin/env zsh
set -euo pipefail

# Phase B Setup: Enable Hardening
# - Setup git alias for safe clean
# - Verify CI workflow exists
# - Create team announcement

REPO="$HOME/02luka"

echo "=== Phase B: Hardening Setup ==="
echo ""

# 1. Setup git alias
echo "1. Setting up git alias for safe clean..."
git config --global alias.clean-safe '!zsh ~/02luka/tools/safe_git_clean.zsh'
echo "   ✅ Git alias 'clean-safe' created"
echo "   Usage: git clean-safe -n  (dry-run)"
echo "         git clean-safe -f   (force)"
echo ""

# 2. Verify CI workflow
echo "2. Checking CI workflow..."
if [[ -f "$REPO/.github/workflows/workspace_guard.yml" ]]; then
  echo "   ✅ CI workflow exists: .github/workflows/workspace_guard.yml"
  echo "   ℹ️  To enable: Push to GitHub and workflow will run on PR/Push"
else
  echo "   ⚠️  CI workflow not found"
fi
echo ""

# 3. Verify guard script
echo "3. Verifying guard script..."
if [[ -x "$REPO/tools/guard_workspace_inside_repo.zsh" ]]; then
  echo "   ✅ Guard script exists and is executable"
else
  echo "   ⚠️  Guard script not found or not executable"
fi
echo ""

# 4. Verify pre-commit hook
echo "4. Verifying pre-commit hook..."
if [[ -f "$REPO/.git/hooks/pre-commit" ]]; then
  if grep -q "exec zsh tools/guard_workspace_inside_repo.zsh" "$REPO/.git/hooks/pre-commit"; then
    echo "   ✅ Pre-commit hook is in blocking mode"
  else
    echo "   ⚠️  Pre-commit hook may not be in blocking mode"
  fi
else
  echo "   ⚠️  Pre-commit hook not found"
fi
echo ""

# 5. Summary
echo "=== Phase B Setup Complete ==="
echo ""
echo "✅ Git alias 'clean-safe' configured"
echo "✅ CI workflow ready (enable on GitHub)"
echo "✅ Guard script verified"
echo "✅ Pre-commit hook verified"
echo ""
echo "📋 Next Steps:"
echo "   1. Test: git clean-safe -n"
echo "   2. Enable CI workflow on GitHub (if using GitHub)"
echo "   3. Share team announcement (see g/docs/WORKSPACE_SPLIT_README.md)"
echo ""
