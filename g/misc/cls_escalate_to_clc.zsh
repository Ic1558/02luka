#!/usr/bin/env zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 '<problem statement or command>'" >&2
  exit 2
fi
BODY="$1"

# Prefer the bridge if present (from earlier phases)
if [[ -x "$HOME/tools/bridge_cls_clc.zsh" ]]; then
  "$HOME/tools/bridge_cls_clc.zsh" \
    --title "CLS Escalation" \
    --priority P2 \
    --tags "cls,escalation" \
    --body <(printf '%s\n' "$BODY") \
    --wait || true
else
  # Fallback: drop a simple WO stub into inbox if bridge is not available
  INBOX="${HOME}/02luka/bridge/inbox/CLC"
  mkdir -p "$INBOX"
  F="${INBOX}/WO-$(date +%Y%m%d-%H%M%S)-ESC.txt"
  printf '%s\n' "$BODY" > "$F"
  echo "📝 Escalation stub dropped: $F"
fi
