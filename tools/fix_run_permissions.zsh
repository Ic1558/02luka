#!/usr/bin/env zsh
# Fix run/ directory permissions and restore scripts
# This script fixes the root-owned run/ directory issue

set -euo pipefail

REPO_ROOT="${1:-$HOME/02luka}"
cd "$REPO_ROOT"

echo "🔧 Fixing run/ directory permissions..."

# Check if we need sudo
if [[ -d "run" ]] && [[ "$(stat -f "%Su" run/ 2>/dev/null || stat -c "%U" run/ 2>/dev/null)" == "root" ]]; then
  echo "📁 run/ directory is owned by root, fixing ownership..."
  echo "   (This may require your password)"
  sudo chown -R "$USER:staff" run/ || {
    echo "❌ Failed to change ownership"
    echo "   Please run manually: sudo chown -R $USER:staff run/"
    exit 1
  }
  echo "✅ Ownership fixed"
fi

# Restore files from git
echo "📥 Restoring scripts from git..."
git checkout HEAD -- run/publish_docs.cjs run/generate_ops_status.cjs run/verify_mirror_integrity.cjs 2>/dev/null || {
  # If checkout fails, restore from commit
  COMMIT="HEAD"
  for script in run/publish_docs.cjs run/generate_ops_status.cjs run/verify_mirror_integrity.cjs; do
    if git show "$COMMIT:$script" > "$script" 2>/dev/null; then
      chmod +x "$script"
      echo "✅ Restored: $script"
    else
      echo "⚠️  Could not restore: $script"
    fi
  done
}

# Ensure executable permissions
chmod +x run/*.cjs 2>/dev/null || true

echo ""
echo "✨ Fix complete!"
echo "📋 Files in run/:"
ls -la run/*.cjs 2>/dev/null || echo "   (no .cjs files found)"

