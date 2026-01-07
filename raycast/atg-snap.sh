#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot
# @raycast.mode fullOutput
# @raycast.packageName 02luka

# Optional parameters:
# @raycast.icon 📸
# @raycast.argument1 { "type": "text", "placeholder": "format (md/json/both)", "optional": true }

# Documentation:
# @raycast.description Generate Antigravity system snapshot (git, processes, logs)
# @raycast.author icmini

cd ~/02luka || exit 1

FORMAT="${1:-md}"

if [[ -f "./tools/atg_snap.zsh" ]]; then
  case "$FORMAT" in
    json)
      ./tools/atg_snap.zsh --json
      ;;
    both)
      ./tools/atg_snap.zsh --both
      ;;
    *)
      ./tools/atg_snap.zsh
      ;;
  esac
else
  echo "⚠️  atg_snap.zsh not found"
  echo "Available snapshots:"
  ls -lht magic_bridge/inbox/*.md 2>/dev/null | head -5
fi
