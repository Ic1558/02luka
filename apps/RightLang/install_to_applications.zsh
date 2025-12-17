#!/usr/bin/env zsh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

zsh "$HERE/build.zsh" >/dev/null

SRC="$HERE/dist/then.app"
DEST="/Applications/then.app"

if [[ ! -d "$SRC" ]]; then
  echo "Missing build output: $SRC" >&2
  exit 1
fi

if [[ -e "$DEST" ]]; then
  TS="$(date +%Y%m%d_%H%M%S)"
  BACKUP="/Applications/then.backup.${TS}.app"
  echo "Existing app found; moving to: $BACKUP"
  mv "$DEST" "$BACKUP"
fi

echo "Installing to: $DEST"
ditto "$SRC" "$DEST"
echo "Installed: $DEST"
