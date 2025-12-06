#!/usr/bin/env zsh
# @file: tools/claude_hooks/review.zsh
# @purpose: Slash command handler for /02luka/review
# @usage: Called by Cursor when user types /02luka/review

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/02luka")"
cd "$REPO_ROOT"

MODE="${1:-staged}"
REVIEW_SCRIPT="$REPO_ROOT/tools/local_agent_review.py"

# Validate mode
case "$MODE" in
  staged|unstaged|last-commit|branch)
    ;;
  *)
    echo "❌ Invalid mode: $MODE"
    echo "Usage: /02luka/review [staged|unstaged|last-commit|branch]"
    exit 1
    ;;
esac

# Check if script exists
if [[ ! -f "$REVIEW_SCRIPT" ]]; then
  echo "❌ Review script not found: $REVIEW_SCRIPT"
  exit 1
fi

# Check for offline flag
OFFLINE_FLAG=""
if [[ "${2:-}" == "--offline" ]] || [[ "${LOCAL_REVIEW_OFFLINE:-0}" == "1" ]]; then
  OFFLINE_FLAG="--offline"
  echo "📴 Running in offline mode (no API call)"
fi

echo "🔍 Running Local Agent Review on: $MODE"
echo ""

# Run review
python3 "$REVIEW_SCRIPT" "$MODE" \
  --format vscode-diagnostics \
  --output "$REPO_ROOT/.vscode/local_agent_review_diagnostics.json" \
  $OFFLINE_FLAG

EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  echo ""
  echo "✅ Review completed!"
  echo "📋 Check Problems panel: Cmd+Shift+M (Mac) or Ctrl+Shift+M (Windows/Linux)"
  echo "📄 Report saved to: g/reports/reviews/"
else
  echo ""
  echo "⚠️  Review found issues (exit code: $EXIT_CODE)"
  echo "📋 Check Problems panel: Cmd+Shift+M"
fi

exit $EXIT_CODE
