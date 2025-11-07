#!/usr/bin/env bash
set -eo pipefail

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

# Guard: enforce pinned faiss-cpu
if [ -x "tools/ci/guard_faiss_pin.zsh" ]; then
  zsh tools/ci/guard_faiss_pin.zsh || {
    echo "❌ faiss-cpu guard failed" >&2
    exit 1
  }
fi

echo ""
echo "✅ Validation complete"


