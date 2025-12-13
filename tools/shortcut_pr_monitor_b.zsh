#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Shortcut B: Open PRs + Actions + Monitor Log
# ═══════════════════════════════════════════════════════════════════════
# One-click: Open PR #404, #405, Actions page, and monitor log
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

LUKA_ROOT="${LUKA_SOT:-${HOME}/02luka}"
REPO_OWNER="icmini"  # Update if needed
REPO_NAME="02luka"   # Update if needed

# Open PR #404
open "https://github.com/${REPO_OWNER}/${REPO_NAME}/pull/404" 2>/dev/null || true

# Open PR #405
open "https://github.com/${REPO_OWNER}/${REPO_NAME}/pull/405" 2>/dev/null || true

# Open Actions page
open "https://github.com/${REPO_OWNER}/${REPO_NAME}/actions" 2>/dev/null || true

# Open monitor log in default editor (or use `open` for TextEdit)
LOG_FILE="${LUKA_ROOT}/g/telemetry/gateway_v3_router.log"
if [[ -f "$LOG_FILE" ]]; then
    # Try to open in VS Code/Cursor, fallback to TextEdit
    code "$LOG_FILE" 2>/dev/null || \
    cursor "$LOG_FILE" 2>/dev/null || \
    open -a TextEdit "$LOG_FILE" 2>/dev/null || true
else
    echo "⚠️  Log file not found: $LOG_FILE"
fi

echo "✅ Opened PR #404, #405, Actions page, and monitor log"
