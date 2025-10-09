#!/usr/bin/env bash
set -euo pipefail
# Use rg if available, fallback to grep for compatibility
if command -v rg >/dev/null 2>&1; then
  rg -n --hidden -S -g '!**/.git/**' "$@"
else
  grep -rn --exclude-dir=.git "$@" .
fi
