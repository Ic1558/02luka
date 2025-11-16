#!/usr/bin/env zsh
set -euo pipefail
MAP="$HOME/02luka/.claude/context-map.json"
# Skip context loading if file doesn't exist or has issues
if [[ -f "$MAP" ]] && command -v jq >/dev/null 2>&1; then
  # Load context variables from JSON map (safely)
  jq -r 'to_entries[] | "\(.key)=\(.value)"' "$MAP" 2>/dev/null | while IFS='=' read -r k v; do
    # Only process if key doesn't contain colon (skip complex keys)
    if [[ "$k" != *:* ]]; then
      key_upper="${(U)k}"
      export "CTX_${key_upper}=${v}"
    fi
  done || true
fi
