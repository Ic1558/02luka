#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Bridge Status
# @raycast.mode fullOutput
# @raycast.packageName 02luka

# Optional parameters:
# @raycast.icon 🌉
# @raycast.argument1 { "type": "text", "placeholder": "command (status/verify/ops-status)", "optional": true }

# Documentation:
# @raycast.description Check Gemini Bridge status, run verify, or ops-status
# @raycast.author icmini

cd ~/02luka || exit 1

COMMAND="${1:-status}"

case "$COMMAND" in
  status)
    ./tools/bridgectl.zsh status
    ;;
  verify)
    ./tools/bridgectl.zsh verify
    ;;
  ops-status|ops)
    ./tools/bridgectl.zsh ops-status
    ;;
  start)
    ./tools/bridgectl.zsh start
    ;;
  stop)
    ./tools/bridgectl.zsh stop
    ;;
  *)
    echo "Usage: bridge-status [status|verify|ops-status|start|stop]"
    echo ""
    ./tools/bridgectl.zsh status
    ;;
esac
