#!/usr/bin/env zsh
set -euo pipefail

echo "=== 1. Checking git status ==="
git status --porcelain

echo ""
echo "=== 2. Verifying run_tool dispatch to save (dry-run) ==="
echo "Note: This verifies the dispatch chain and truth sync."
zsh tools/run_tool.zsh save --dry-run

echo ""
echo "=== Verification Complete ==="