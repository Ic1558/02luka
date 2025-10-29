#!/bin/bash
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Validation Script - Phase 4/5/6 Smoke Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify dependencies
echo "✅ Checking dependencies..."
command -v jq >/dev/null 2>&1 || { echo "❌ jq not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "❌ yq not found"; exit 1; }
command -v redis-cli >/dev/null 2>&1 || { echo "❌ redis-cli not found"; exit 1; }

echo "✅ All dependencies present"

# Run smoke tests
echo ""
echo "🔥 Running smoke tests..."
bash scripts/smoke.sh

echo ""
echo "✅ Validation complete"
