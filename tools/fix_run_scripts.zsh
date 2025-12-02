#!/usr/bin/env zsh
# Fix run/ scripts - Run this to restore the missing workflow scripts
# Usage: ./tools/fix_run_scripts.zsh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "🔧 Fixing run/ directory and restoring scripts..."
echo ""

# Step 1: Fix ownership (requires sudo password)
if [[ -d "run" ]] && [[ "$(stat -f "%Su" run/ 2>/dev/null || stat -c "%U" run/ 2>/dev/null)" == "root" ]]; then
  echo "📁 run/ directory is owned by root"
  echo "   Fixing ownership (you may be prompted for your password)..."
  sudo chown -R "$USER:staff" run/
  echo "✅ Ownership fixed"
fi

# Step 2: Restore files from git
echo "📥 Restoring scripts from git..."
if git restore --source=HEAD run/publish_docs.cjs run/generate_ops_status.cjs run/verify_mirror_integrity.cjs 2>/dev/null; then
  echo "✅ Files restored via git restore"
else
  # Fallback: restore manually
  echo "   Using manual restore..."
  git show HEAD:run/publish_docs.cjs > run/publish_docs.cjs
  git show HEAD:run/generate_ops_status.cjs > run/generate_ops_status.cjs
  git show HEAD:run/verify_mirror_integrity.cjs > run/verify_mirror_integrity.cjs
  echo "✅ Files restored manually"
fi

# Step 3: Ensure executable permissions
chmod +x run/*.cjs 2>/dev/null || true

echo ""
echo "✨ Fix complete!"
echo ""
echo "📋 Restored files:"
ls -lh run/*.cjs 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}'

echo ""
echo "✅ All workflow scripts are now available!"
echo "   - run/publish_docs.cjs"
echo "   - run/generate_ops_status.cjs"
echo "   - run/verify_mirror_integrity.cjs"
echo "   - g/tools/build_ops_mirror.zsh"

