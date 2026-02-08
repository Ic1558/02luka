#!/usr/bin/env bash
set -euo pipefail

# Required main workspace (must always exist)
REQUIRED_WS="02luka.code-workspace"

if [[ ! -f "$REQUIRED_WS" ]]; then
  echo "MISSING REQUIRED WORKSPACE: $REQUIRED_WS"
  exit 1
fi

# Optional: warn (but do NOT fail) if workspace filenames contain spaces
HAS_SPACE_WS="$(find . -maxdepth 1 -name "*.code-workspace" -print | grep " " || true)"

if [[ -n "$HAS_SPACE_WS" ]]; then
  echo "WARNING: workspace filenames with spaces detected:"
  echo "$HAS_SPACE_WS"
fi

echo "Workspace guard passed."
