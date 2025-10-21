#!/usr/bin/env zsh
set -euo pipefail
ROOT="${1:-.}"
echo "Scanning for blocking fs.writeFileSync …"
grep -RIn "fs\.writeFileSync\(" \
  "$ROOT/knowledge" "$ROOT/agents" "$ROOT/memory" "$ROOT/g" 2>/dev/null \
  | grep -vE "writeArtifacts|helpers|node_modules" || {
    echo "No raw writeFileSync calls found (good)."; exit 0; }
echo "⚠ Found raw writeFileSync calls above. Replace with writeArtifacts()."; exit 2
