#!/usr/bin/env bash
# Universal repository root resolver with duplicate clone detection
# Works in devcontainer (/workspaces/02luka-repo) and host (various locations)
set -euo pipefail

# Try to find repo root using git, fallback to current directory
if REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  export REPO_ROOT
else
  # Fallback: assume we're in the repo root
  export REPO_ROOT="$(pwd)"
fi

# Verify this looks like the 02luka repo
if [[ ! -f "$REPO_ROOT/.codex/preflight.sh" ]] || [[ ! -d "$REPO_ROOT/g" ]]; then
  echo "WARNING: $REPO_ROOT doesn't appear to be the 02luka repository" >&2
fi

# Detect duplicate clones (multi-location scan)
DUPLICATE_CLONES=()
SEARCH_PATHS=(
  "$HOME/dev/02luka-repo"
  "$HOME/local-repos/02luka-repo"
  "$HOME/Desktop/02luka-repo"
  "$HOME/Downloads/02luka-repo"
  "/workspaces/02luka-repo"
)

CURRENT_COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

for clone_path in "${SEARCH_PATHS[@]}"; do
  # Skip if it's the current repo
  [[ "$clone_path" == "$REPO_ROOT" ]] && continue

  # Check if it's a valid git repo
  if [[ -d "$clone_path/.git" ]]; then
    clone_commit=$(git -C "$clone_path" rev-parse --short HEAD 2>/dev/null || echo "unknown")

    # Record if commits differ
    if [[ "$clone_commit" != "$CURRENT_COMMIT" ]] && [[ "$clone_commit" != "unknown" ]]; then
      DUPLICATE_CLONES+=("$clone_path (commit: $clone_commit)")
    fi
  fi
done

# Export for use in other scripts
export REPO_ROOT
export CURRENT_COMMIT
export DUPLICATE_CLONES
