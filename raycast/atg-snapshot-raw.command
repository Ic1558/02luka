#!/usr/bin/env zsh
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot RAW (Raw → Clipboard)
# @raycast.mode silent
# @raycast.packageName 02luka Antigravity
# @raycast.description Generate RAW snapshot → drop to magic_bridge/inbox → copy RAW to clipboard
# @raycast.icon 📄

set -euo pipefail

REPO="$HOME/02luka"
BRIDGE="$REPO/magic_bridge"
INBOX="$BRIDGE/inbox"
mkdir -p "$INBOX"

OUT_MD="$INBOX/atg_snapshot.md"

# Reuse the main command logic by invoking it in full mode if present
if [[ -x "$HOME/02luka/raycast/atg-snapshot.command" ]]; then
  "$HOME/02luka/raycast/atg-snapshot.command" full >/dev/null 2>&1 || true
else
  # Fallback: minimal raw write
  ts_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ts_local="$(date +%Y-%m-%dT%H:%M:%S%z)"
  {
    echo "# 📄 Antigravity System Snapshot (RAW)"
    echo "**Timestamp (UTC):** $ts_utc"
    echo "**Timestamp (Local):** $ts_local"
    echo "**Repo Root:** $REPO"
    echo
    echo "## Runtime"
    echo '```text'
    (pgrep -fl 'Antigravity|antigravity|codex|gemini_bridge|fs_watcher|api_server|claude-proxy|language_server' 2>/dev/null | head -n 80) || true
    echo '```'
  } > "$OUT_MD"
fi

pbcopy < "$OUT_MD" || true
echo "✅ RAW snapshot copied to clipboard."
echo "RAW: $OUT_MD"
