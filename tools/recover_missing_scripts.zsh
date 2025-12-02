#!/usr/bin/env zsh
# Recover missing workflow scripts
# Fixes permissions and restores publish_docs.cjs, generate_ops_status.cjs, verify_mirror_integrity.cjs

set -euo pipefail

REPO_ROOT="${1:-$HOME/02luka}"
cd "$REPO_ROOT"

echo "🔧 Recovering missing workflow scripts..."

# Fix run/ directory permissions
if [[ -d "run" ]]; then
  echo "📁 Fixing run/ directory permissions..."
  sudo chown -R "$USER:staff" run/ || {
    echo "⚠️  Could not change ownership (may need sudo password)"
    echo "   Run manually: sudo chown -R $USER:staff run/"
  }
fi

# Restore scripts from git history
COMMIT="2a643c6b4~1"

echo "📥 Restoring scripts from commit $COMMIT..."

for script in run/publish_docs.cjs run/generate_ops_status.cjs run/verify_mirror_integrity.cjs; do
  if git show "$COMMIT:$script" > "$script" 2>/dev/null; then
    chmod +x "$script"
    echo "✅ Restored: $script"
  else
    echo "❌ Failed to restore: $script"
  fi
done

echo ""
echo "✨ Recovery complete!"
echo "📋 Restored files:"
ls -la run/*.cjs 2>/dev/null || echo "   (no .cjs files found)"

