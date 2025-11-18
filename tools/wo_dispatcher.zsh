#!/usr/bin/env zsh
# Work Order dispatcher: route WO YAML into the correct engine inbox.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <wo_file>" >&2
  exit 1
fi

WO_FILE="$1"
BASE="${LUKA_SOT:-$HOME/02luka}"

if ! command -v yq >/dev/null 2>&1; then
  echo "[wo_dispatcher] yq is required to parse work orders" >&2
  exit 1
fi

if [[ ! -f "$WO_FILE" ]]; then
  echo "[wo_dispatcher] WO file not found: $WO_FILE" >&2
  exit 1
fi

ENGINE=$(yq -r '.engine // "CLC"' "$WO_FILE")
if [[ "$ENGINE" == "gemini" ]]; then
  ENGINE="GEMINI"
fi

case "$ENGINE" in
  "CLC")    INBOX="$BASE/bridge/inbox/CLC" ;;
  "LPE")    INBOX="$BASE/bridge/inbox/LPE" ;;
  "GEMINI") INBOX="$BASE/bridge/inbox/GEMINI" ;;
  *)
    echo "[wo_dispatcher] Unknown engine: $ENGINE" >&2
    exit 1
    ;;
esac

mkdir -p "$INBOX"

WO_ID=$(yq -r '.wo_id // .id // ""' "$WO_FILE" 2>/dev/null || true)
if [[ -z "$WO_ID" || "$WO_ID" == "null" ]]; then
  WO_ID="${WO_FILE:t:r}"
fi
EXT="${WO_FILE##*.}"
DEST="$INBOX/${WO_ID}.${EXT}"

tmp_dest="$DEST.$$"
cp "$WO_FILE" "$tmp_dest"
mv "$tmp_dest" "$DEST"

echo "[wo_dispatcher] Routed $WO_FILE -> $DEST (engine=$ENGINE)"
