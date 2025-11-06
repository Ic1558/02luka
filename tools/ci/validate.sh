#!/usr/bin/env bash
set -eo pipefail

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

# Quick guard: Check for non-portable patterns
echo ""
echo "🔍 Checking for non-portable patterns..."
if grep -R --include='*.sh' --include='*.zsh' -nE '\bshopt\b' . >/dev/null 2>&1; then
  echo "❌ Found 'shopt' (non-portable) in scripts"
  grep -R --include='*.sh' --include='*.zsh' -nE '\bshopt\b' . || true
  echo "⚠️  Consider using find+while instead"
fi

if grep -R --include='*.sh' --include='*.zsh' -nE 'for +[a-zA-Z_][a-zA-Z0-9_]* +in +[^|]*\*[^|]*; do' . >/dev/null 2>&1; then
  echo "⚠️  Found glob-for loops — consider find+while for portability"
  grep -R --include='*.sh' --include='*.zsh' -nE 'for +[a-zA-Z_][a-zA-Z0-9_]* +in +[^|]*\*[^|]*; do' . || true
fi
echo "✅ Pattern check complete"

# Check if SKIP_BOSS_API is set to skip server start
if [[ "${SKIP_BOSS_API:-0}" == "1" ]] || [[ "${SKIP_BOSS:-0}" == "1" ]]; then
  echo "🔥 Running smoke tests (server-less mode, SKIP_BOSS_API=1)..."
  if [[ -x scripts/smoke.sh ]]; then
    bash scripts/smoke.sh
  else
    echo "⚠️  scripts/smoke.sh not found or not executable; skipping smoke tests"
  fi
else
  echo "🔥 Running smoke tests (managed server)..."
  if [[ -x scripts/smoke_with_server.sh ]]; then
    bash scripts/smoke_with_server.sh
  elif [[ -x scripts/smoke.sh ]]; then
    echo "⚠️  scripts/smoke_with_server.sh not found; falling back to smoke.sh"
    bash scripts/smoke.sh
  else
    echo "⚠️  No smoke script found; skipping smoke tests"
  fi
fi

echo ""
echo "✅ Validation complete"


