#!/usr/bin/env zsh
set -euo pipefail

echo "=== Verifying Phase 13 (Hook Planner) with Debug Output ==="
export BUILD_CORE_HISTORY_DEBUG=1
zsh tools/build_core_history.zsh
echo "=== Verification Complete ==="