#!/usr/bin/env zsh
# @purpose: Toggle git auto-sync on/off
# @usage: git_sync_toggle.zsh [on|off|status]

set -euo pipefail

PAUSE_FLAG="$HOME/02luka/g/.git_auto_sync_paused"
ACTION="${1:-status}"

case "$ACTION" in
    off|pause)
        touch "$PAUSE_FLAG"
        echo "✅ Git auto-sync PAUSED"
        echo "   Auto-commits will not run until you enable sync again"
        echo "   To re-enable: $0 on"
        ;;
    on|resume)
        rm -f "$PAUSE_FLAG"
        echo "✅ Git auto-sync ENABLED"
        echo "   Auto-commits will run every 30 minutes on ai/ branches"
        ;;
    status)
        if [[ -f "$PAUSE_FLAG" ]]; then
            echo "⏸️  Git auto-sync is PAUSED"
            echo "   To enable: $0 on"
        else
            echo "▶️  Git auto-sync is ENABLED"
            echo "   To pause: $0 off"
        fi
        ;;
    *)
        echo "Usage: $0 [on|off|status]"
        echo "  on/resume  - Enable auto-sync"
        echo "  off/pause  - Pause auto-sync"
        echo "  status     - Check current status (default)"
        exit 1
        ;;
esac
