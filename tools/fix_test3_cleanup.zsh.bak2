#!/usr/bin/env zsh
# Quick fix: Restore symlinks broken by Test 3
set -euo pipefail

REPO="$HOME/02luka"
WS="$HOME/02luka_ws"

cd "$REPO"

echo "=== Restoring symlinks broken by Test 3 ==="
echo ""

# Restore g/data
if [[ -d g/data && ! -L g/data ]]; then
  echo "Restoring g/data..."
  rm -rf g/data
  mkdir -p "$WS/g/data"
  ln -sfn "$WS/g/data" g/data
  echo "✅ g/data restored"
fi

# Restore g/telemetry
if [[ -d g/telemetry && ! -L g/telemetry ]]; then
  echo "Restoring g/telemetry..."
  rm -rf g/telemetry
  mkdir -p "$WS/g/telemetry"
  ln -sfn "$WS/g/telemetry" g/telemetry
  echo "✅ g/telemetry restored"
fi

echo ""
echo "=== Verifying guard ==="
if zsh tools/guard_workspace_inside_repo.zsh; then
  echo ""
  echo "✅ All symlinks restored and guard passes"
else
  echo ""
  echo "❌ Guard still fails - check manually"
  exit 1
fi
