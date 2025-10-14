#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

echo "🔄 Refreshing boss catalogs and dashboard..."
echo

# 1. Regenerate boss catalogs (reports + memory indexes)
if [ -x scripts/generate_boss_catalogs.sh ]; then
  ./scripts/generate_boss_catalogs.sh
else
  echo "⚠️  scripts/generate_boss_catalogs.sh not found or not executable"
fi

echo

# 2. Regenerate daily HTML dashboard
if [ -x scripts/generate_boss_daily_html.sh ]; then
  ./scripts/generate_boss_daily_html.sh
else
  echo "⚠️  scripts/generate_boss_daily_html.sh not found or not executable"
fi

echo
echo "✅ Boss refresh complete!"
echo "   - boss/reports/index.md (reports catalog)"
echo "   - boss/memory/index.md (memory catalog)"
echo "   - views/ops/daily/index.html (daily dashboard)"
