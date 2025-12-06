#!/usr/bin/env zsh
set -euo pipefail

# Fast lint checks
echo "🔍 pre-commit: fast lint stub (OK)"
# TODO: plug real fast checks (shfmt/shellcheck/yamllint/git grep deny-list)

# Local Agent Review (optional, can be skipped)
if [[ "${LOCAL_REVIEW_SKIP:-0}" != "1" ]] && [[ "${LOCAL_REVIEW_ENABLED:-0}" == "1" ]]; then
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  REVIEW_SCRIPT="$REPO_ROOT/tools/local_agent_review.py"
  
  if [[ -f "$REVIEW_SCRIPT" ]] && command -v python3 >/dev/null 2>&1; then
    # Check if there are staged changes
    if git diff --cached --quiet; then
      echo "📝 pre-commit: No staged changes to review"
    else
      echo "🔍 pre-commit: Running Local Agent Review on staged changes..."
      # Run in background, don't block commit
      python3 "$REVIEW_SCRIPT" staged \
        --format vscode-diagnostics \
        --output "$REPO_ROOT/.vscode/local_agent_review_diagnostics.json" \
        --quiet 2>&1 | head -5 || true
      echo "✅ pre-commit: Review completed (check Problems panel: Cmd+Shift+M)"
    fi
  fi
fi

exit 0
