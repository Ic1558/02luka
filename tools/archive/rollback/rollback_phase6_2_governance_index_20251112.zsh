#!/usr/bin/env zsh
set -euo pipefail

# Rollback script for Phase 6.2 - Governance Index & Visualization
# Generated: 2025-11-12

REPO="$HOME/02luka"
cd "$REPO"

echo "=== Phase 6.2 Rollback ==="
echo ""

# 1. Remove index generator script
if [[ -f tools/governance_index_generator.zsh ]]; then
  rm -f tools/governance_index_generator.zsh
  echo "✅ Removed: tools/governance_index_generator.zsh"
fi

# 2. Revert weekly recap generator
if git diff HEAD -- tools/weekly_recap_generator.zsh >/dev/null 2>&1; then
  git checkout HEAD -- tools/weekly_recap_generator.zsh
  echo "✅ Reverted: tools/weekly_recap_generator.zsh"
fi

# 3. Remove generated files
rm -f g/reports/system/index.json
rm -f g/reports/system/trends_snapshot_*.html
echo "✅ Removed generated files"

# 4. Remove from .gitignore (optional - keep for future)
# git checkout HEAD -- .gitignore

echo ""
echo "✅ Rollback complete"
echo ""
echo "To fully restore:"
echo "  git checkout HEAD -- tools/weekly_recap_generator.zsh"
echo "  git checkout HEAD -- .gitignore"

