#!/usr/bin/env zsh
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot RAW (Raw → Clipboard)
# @raycast.mode silent
# @raycast.packageName 02luka Antigravity
# @raycast.icon 🧾
# @raycast.description Capture raw snapshot and copy to clipboard (also drops into magic_bridge/inbox).
# @raycast.needsConfirmation false

set -euo pipefail

ROOT="$HOME/02luka"
BRIDGE="$ROOT/magic_bridge"
INBOX="$BRIDGE/inbox"
mkdir -p "$INBOX"

repo="$ROOT"
out="$INBOX/atg_snapshot.md"

tmp="$(mktemp "${TMPDIR:-/tmp}/atg_snapshot_raw.XXXXXX.md")"
utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
localts="$(date +"%Y-%m-%dT%H:%M:%S%z")"
branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
head="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo '?')"

{
  echo "# 🧾 Antigravity System Snapshot (RAW)"
  echo "**Timestamp (UTC):** $utc"
  echo "**Timestamp (Local):** $localts"
  echo "**Repo Root:** $repo"
  echo "**Branch:** $branch"
  echo "**HEAD:** $head"
  echo
  echo "## 1. Git Context"
  echo "### Command: \`git -C '$repo' status --porcelain=v1\`"
  echo '```text'
  git -C "$repo" status --porcelain=v1 2>/dev/null || true
  echo '```'
  echo
  echo "### Command: \`git -C '$repo' log -5 --oneline\`"
  echo '```text'
  git -C "$repo" log -5 --oneline 2>/dev/null || true
  echo '```'
  echo
  echo "### Command: \`git -C '$repo' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'\`"
  echo '```text'
  (git -C "$repo" diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)') | sed -e 's/[[:space:]]\+$//'
  echo '```'
  echo
  echo "## 2. Runtime Context"
  echo '```text'
  (pgrep -fl "gemini_bridge|bridge\.sh|api_server|antigravity|fs_watcher|python" | grep -v atg_snap) 2>/dev/null || true
  echo '```'
  echo
  echo "## 3. Telemetry Pulse (last 80)"
  echo '```text'
  tail -n 80 "$repo/g/telemetry/atg_runner.jsonl" 2>/dev/null || echo "_File not found: atg_runner.jsonl_"
  echo '```'
  echo
  echo "## 4. Bridge Logs (last 120 lines)"
  echo "### /tmp/com.antigravity.bridge.stderr.log"
  echo '```text'
  tail -n 120 /tmp/com.antigravity.bridge.stderr.log 2>/dev/null || true
  echo '```'
  echo
  echo "### /tmp/com.antigravity.bridge.stdout.log"
  echo '```text'
  tail -n 120 /tmp/com.antigravity.bridge.stdout.log 2>/dev/null || true
  echo '```'
  echo
  echo "## 5. Metadata"
  echo "Snapshot Version: 2.2"
  echo "Mode: RawClipboard"
} > "$tmp"

# copy to clipboard first (before moving)
pbcopy < "$tmp" || true

# also drop into inbox so summary is produced
mv -f "$tmp" "$out"

echo "OK: copied RAW to clipboard + wrote $(basename "$out")"
