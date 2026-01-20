#!/usr/bin/env zsh
# ======================================================================
# Digest Refresh Cron Job - Phase 4 Reliability Fallback
# Runs every 5 minutes to ensure digest stays fresh
# ======================================================================

set -euo pipefail

# Determine repo root
REPO_ROOT="${LUKA_ROOT:-$HOME/02luka}"

# Change to repo directory
cd "$REPO_ROOT" || exit 1

# Run digest update (quiet mode for cron)
python3 g/tools/update_work_notes_digest.py --lines 200 --incremental --quiet 2>/dev/null || true

# Exit successfully (cron doesn't care about failures)
exit 0
