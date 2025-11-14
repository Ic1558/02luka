#!/usr/bin/env zsh
# Rollback script for Smart CLS Watcher deployment
# Generated: 2025-11-15

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔄 Rolling back CLS Watcher deployment..."

# Remove deployed files
if [[ -f "$REPO_ROOT/tools/watch_cls_alive.zsh" ]]; then
  echo "  Removing watch_cls_alive.zsh..."
  rm -f "$REPO_ROOT/tools/watch_cls_alive.zsh"
fi

if [[ -f "$REPO_ROOT/tools/check-cls" ]]; then
  echo "  Removing check-cls..."
  rm -f "$REPO_ROOT/tools/check-cls"
fi

# Remove alias from .zshrc (if added)
if grep -q 'alias check-cls=' "$HOME/.zshrc" 2>/dev/null; then
  echo "  Removing check-cls alias from .zshrc..."
  sed -i.bak '/alias check-cls=/d' "$HOME/.zshrc" 2>/dev/null || true
fi

# Note: State and log files are preserved (may contain useful data)
echo "  Note: State and log files preserved in ~/02luka/state and ~/02luka/logs"

echo ""
echo "✅ Rollback complete"
echo ""
echo "To restore from backup, check: g/reports/deployments/cls_watcher_*/"
