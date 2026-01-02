#!/usr/bin/env zsh
set -euo pipefail

ROOT="$HOME/02luka"
PLIST_SRC="$ROOT/LaunchAgents/com.02luka.fs_watcher.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.02luka.fs_watcher.plist"
LOG_DIR="$ROOT/logs"

[[ -f "$PLIST_SRC" ]] || { echo "missing plist: $PLIST_SRC" >&2; exit 1; }
[[ -d "$ROOT" ]] || { echo "missing repo root: $ROOT" >&2; exit 1; }

mkdir -p "$LOG_DIR"
chmod +x "$ROOT/tools/fs_watcher.py"
cp -f "$PLIST_SRC" "$PLIST_DST"

launchctl bootout gui/"$(id -u)" "$PLIST_DST" 2>/dev/null || true
launchctl bootstrap gui/"$(id -u)" "$PLIST_DST"
launchctl kickstart -k gui/"$(id -u)"/com.02luka.fs_watcher
launchctl list | grep com.02luka.fs_watcher || { echo "fs_watcher not listed" >&2; exit 2; }
echo "fs_watcher loaded"
