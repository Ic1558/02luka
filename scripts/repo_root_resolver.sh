#!/usr/bin/env bash
# Universal repository root resolver
# Works in devcontainer (/workspaces/02luka-repo) and host (~/dev/02luka-repo)
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

# Export for use in other scripts
export REPO_ROOT
