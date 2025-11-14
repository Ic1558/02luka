#!/usr/bin/env bash
set -euo pipefail

# Respect CI skip flags
if [[ "${SKIP_BOSS_API:-0}" == "1" ]]; then
  echo "CI: SKIP_BOSS_API=1 → ไม่สตาร์ท boss-api ในรอบนี้"
  export SKIP_BOSS=1
fi

if [[ "${CI_QUIET:-0}" == "1" ]]; then
  echo "CI: CI_QUIET=1 → ทำงานแบบเงียบ"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Validation Script - Smoke Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if SKIP_BOSS_API is set to skip server start
if [[ "${SKIP_BOSS_API:-0}" == "1" ]]; then
  echo "🔥 Running smoke tests (server-less mode, SKIP_BOSS_API=1)..."
  bash scripts/smoke.sh
else
  echo "🔥 Running smoke tests (managed server)..."
  bash scripts/smoke_with_server.sh
fi

echo ""
echo "✅ Validation complete"
