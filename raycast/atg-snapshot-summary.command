#!/usr/bin/env zsh
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot SUMMARY
# @raycast.mode silent
# @raycast.packageName 02luka
# @raycast.icon 🚀
# @raycast.description Smart summary → Core History → clipboard
# @raycast.needsConfirmation false

set -euo pipefail

ROOT="$HOME/02luka"
BRIDGE="$ROOT/magic_bridge"
INBOX="$BRIDGE/inbox"
mkdir -p "$INBOX"

repo="$ROOT"
out="$INBOX/atg_snapshot.md"

# Generate full snapshot for bridge processing
tmp="$(mktemp "${TMPDIR:-/tmp}/atg_snapshot.XXXXXX.md")"
utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
localts="$(date +"%Y-%m-%dT%H:%M:%S%z")"
branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
head="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo '?')"

{
  echo "# 🤯 Antigravity System Snapshot"
  echo "**Timestamp (UTC):** $utc"
  echo "**Timestamp (Local):** $localts"
  echo "**Repo Root:** $repo"
  echo "**Branch:** $branch"
  echo "**HEAD:** $head"
  echo
  echo "## 1. Git Context"
  echo '```text'
  git -C "$repo" status --porcelain=v1 2>/dev/null || true
  echo '```'
  echo
  echo "## 2. Recent Commit"
  echo '```text'
  git -C "$repo" log -1 --oneline 2>/dev/null || true
  echo '```'
  echo
  echo "## 3. Runtime"
  echo '```text'
  (pgrep -fl "gemini_bridge|mary|opal|fs_watcher" | grep -v atg_snap) 2>/dev/null || echo "(no processes)"
  echo '```'
  echo
  echo "## 4. Telemetry (tail -20)"
  echo '```text'
  tail -n 20 "$repo/g/telemetry/decision_log.jsonl" 2>/dev/null | tail -n 3 || echo "(no telemetry)"
  echo '```'
} > "$tmp"

# Atomic move to bridge inbox
mv -f "$tmp" "$out"

# Wait for async processing
sleep 1

# Build aggregated Core History (SUMMARY mode)
cd "$ROOT"
if [[ -x "tools/build_core_history.zsh" ]]; then
  zsh tools/build_core_history.zsh > /dev/null 2>&1 || true
fi

# Copy summary to clipboard
if [[ -f "g/core_history/latest.md" ]]; then
  cat "g/core_history/latest.md" | pbcopy
  echo "✓ Core History SUMMARY → clipboard"
else
  cat "$out" | pbcopy
  echo "✓ Snapshot → clipboard (fallback)"
fi
