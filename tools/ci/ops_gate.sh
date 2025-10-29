#!/bin/bash
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 Ops Gate - Phase 5/6/7 Quality Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify dependencies
echo "✅ Checking dependencies..."
command -v jq >/dev/null 2>&1 || { echo "❌ jq not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "❌ yq not found"; exit 1; }

echo "✅ All dependencies present"

# Create required directories
echo ""
echo "📁 Creating required directories..."
mkdir -p g/memory g/reports g/telemetry

# Run smoke tests
echo ""
echo "🔥 Running smoke tests..."
bash scripts/smoke.sh

# Run self-review (non-blocking)
echo ""
echo "🔍 Running self-review (non-blocking)..."
node agents/reflection/self_review.cjs --days=7 >/dev/null || echo "⚠️  self_review skipped (requires existing data)"

echo ""
echo "✅ Ops gate checks complete"
