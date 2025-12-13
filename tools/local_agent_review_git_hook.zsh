#!/usr/bin/env zsh
# @file: tools/local_agent_review_git_hook.zsh
# @purpose: Git hook to auto-run Local Agent Review on staged changes
# @usage: Install as pre-commit hook: ln -s ../../tools/local_agent_review_git_hook.zsh .git/hooks/pre-commit

set -euo pipefail

# Get repo root
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Check if Local Agent Review is enabled
if [[ "${LOCAL_REVIEW_ENABLED:-0}" != "1" ]]; then
  exit 0  # Skip if not enabled
fi

# Check if ANTHROPIC_API_KEY is set (skip if offline mode only)
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "[local-review] Skipping: ANTHROPIC_API_KEY not set (use --offline mode)"
  exit 0
fi

# Run Local Agent Review on staged changes
REVIEW_SCRIPT="$REPO_ROOT/tools/local_agent_review.py"

if [[ ! -f "$REVIEW_SCRIPT" ]]; then
  echo "[local-review] Warning: Review script not found: $REVIEW_SCRIPT"
  exit 0
fi

echo "[local-review] Running review on staged changes..."

# Run review (non-blocking, but show output)
python3 "$REVIEW_SCRIPT" staged \
  --format vscode-diagnostics \
  --output "$REPO_ROOT/.vscode/local_agent_review_diagnostics.json" \
  --quiet || {
  echo "[local-review] Review found issues. Check Problems panel in Cursor."
  # Don't block commit, just warn
  exit 0
}

echo "[local-review] Review completed. Check Problems panel for diagnostics."
