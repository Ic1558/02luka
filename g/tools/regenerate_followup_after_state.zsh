#!/usr/bin/env zsh
# regenerate_followup_after_state.zsh
# Regenerate followup.json after state files are written
# Can be called as a post-processing hook by processors

set -euo pipefail

BASE="${LUKA_SOT:-/Users/icmini/02luka}"
GENERATOR="$BASE/tools/claude_tools/generate_followup_data.zsh"

# Check if generator exists
if [[ ! -x "$GENERATOR" ]]; then
  echo "WARN: generate_followup_data.zsh not found at $GENERATOR" >&2
  exit 0  # Don't fail if generator missing
fi

# Regenerate followup.json
"$GENERATOR" || {
  echo "WARN: Failed to regenerate followup.json" >&2
  exit 0  # Don't fail - this is a post-processing step
}

exit 0
