#!/usr/bin/env zsh
# Restore run/ scripts from git (fixes permission issues)
# Usage: ./tools/restore_run_scripts.zsh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "🔧 Restoring run/ scripts from git..."
echo ""

# Check if run/ is root-owned
if [[ -d "run" ]] && [[ "$(stat -f "%Su" run/ 2>/dev/null || stat -c "%U" run/ 2>/dev/null)" == "root" ]]; then
  echo "📁 run/ directory is owned by root"
  echo "   Fixing ownership (you may be prompted for your password)..."
  sudo chown -R "$USER:staff" run/
  echo "✅ Ownership fixed"
fi

# Restore files from HEAD
echo "📥 Restoring scripts from git HEAD..."
git restore run/publish_docs.cjs run/generate_ops_status.cjs run/verify_mirror_integrity.cjs 2>&1 || {
  echo "⚠️  Could not restore (permission issue)"
  echo "   Files are in git tree and will be available in GitHub Actions"
  exit 0
}

# Set executable permissions
chmod +x run/*.cjs 2>/dev/null || true

echo ""
echo "✨ Restoration complete!"
echo ""
echo "📋 Restored files:"
ls -lh run/*.cjs 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}'

