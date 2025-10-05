#!/usr/bin/env bash
# Resolve logical keys (namespace:key) to physical paths using mapping.json
# Usage: path_resolver.sh human:inbox  →  /abs/path/to/boss/inbox

set -euo pipefail

# --- find repo root (prefer SOT_PATH, fall back to current repo) ---
if [[ -n "${SOT_PATH:-}" && -d "$SOT_PATH" ]]; then
  ROOT="$SOT_PATH"
elif git rev-parse --show-toplevel >/dev/null 2>&1; then
  ROOT="$(git rev-parse --show-toplevel)"
else
  ROOT="$(pwd)"
fi

MAP="$ROOT/f/ai_context/mapping.json"

if [[ ! -f "$MAP" ]]; then
  echo "ERROR: mapping.json not found at $MAP" >&2
  exit 127
fi

if [[ $# -ne 1 || "$1" != *:* ]]; then
  echo "Usage: $(basename "$0") namespace:key" >&2
  exit 2
fi

NS="${1%%:*}"
KEY="${1##*:}"

REL=$(jq -r --arg ns "$NS" --arg k "$KEY" '.namespaces[$ns][$k] // empty' "$MAP")
if [[ -z "$REL" || "$REL" == "null" ]]; then
  echo "ERROR: unknown mapping key: $NS:$KEY" >&2
  exit 3
fi

# Normalize to absolute path so Stream Mode symlinks stay consistent
ABS="$ROOT/$REL"
ABS=$(python3 -c 'import os, sys; print(os.path.abspath(sys.argv[1]))' "$ABS")

echo "$ABS"
