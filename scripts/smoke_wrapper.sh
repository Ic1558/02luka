#!/usr/bin/env bash
# Wrapper script to use CI-friendly smoke test instead of local services test
set -euo pipefail

# Use CI-friendly smoke test if available, otherwise fall back to local test
if [ -f "scripts/smoke.sh" ]; then
  echo "🧪 Using CI-friendly smoke test..."
  bash scripts/smoke.sh
else
  echo "⚠️  CI-friendly smoke test not found, falling back to local test..."
  if [ -f "run/smoke_api_ui.sh" ]; then
    bash run/smoke_api_ui.sh
  else
    echo "❌ No smoke test found"
    exit 1
  fi
fi
