#!/usr/bin/env zsh
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot RAW (Raw → Clipboard)
# @raycast.mode silent
# @raycast.packageName 02luka Antigravity
# @raycast.icon 📄
# @raycast.description Generate RAW snapshot only and copy RAW to clipboard
# @raycast.author 02luka
# @raycast.needsConfirmation false

set -euo pipefail

ROOT="$HOME/02luka"
INBOX="$ROOT/magic_bridge/inbox"
MD="$INBOX/atg_snapshot.md"

mkdir -p "$INBOX"

timestamp_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
timestamp_local="$(date +"%Y-%m-%dT%H:%M:%S%z")"
repo_root="$ROOT"

_run() {
  local cmd="$1"
  echo "### Command: \`$cmd\`" >> "$MD"
  echo '```text' >> "$MD"
  eval "$cmd" >> "$MD" 2>&1 || true
  echo '```' >> "$MD"
  echo >> "$MD"
}

: > "$MD"
{
  echo "# 📸 Antigravity System Snapshot (RAW)"
  echo "**Timestamp (UTC):** $timestamp_utc"
  echo "**Timestamp (Local):** $timestamp_local"
  echo "**Repo Root:** $repo_root"
  if command -v git >/dev/null 2>&1; then
    echo "**Branch:** $(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
    echo "**HEAD:** $(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  fi
  echo
  echo "## 1. Git Context 🌳"
} >> "$MD"

_run "git -C '$repo_root' status --porcelain=v1"
_run "git -C '$repo_root' log -1 --oneline"
_run "git -C '$repo_root' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'"
echo "## 2. Runtime Context ⚙️" >> "$MD"
_run "pgrep -fl 'gemini_bridge|bridge\\.sh|api_server|antigravity|fs_watcher|python' | grep -v atg_snap || true"
echo "## 3. Telemetry Pulse 📊" >> "$MD"
_run "tail -n 50 '$repo_root/g/telemetry/atg_runner.jsonl' 2>/dev/null || echo '_File not found: atg_runner.jsonl_'"
_run "tail -n 50 '$repo_root/g/telemetry/fs_index.jsonl' 2>/dev/null || echo '_File not found: fs_index.jsonl_'"
echo "## 4. System Logs (Errors) 🔴" >> "$MD"
_run "tail -n 50 '/tmp/com.02luka.fs_watcher.stderr.log' 2>/dev/null || true"
_run "tail -n 50 '/tmp/com.02luka.fs_watcher.stdout.log' 2>/dev/null || true"
_run "tail -n 50 '/tmp/com.antigravity.bridge.stderr.log' 2>/dev/null || true"
_run "tail -n 50 '/tmp/com.antigravity.bridge.stdout.log' 2>/dev/null || true"
echo "## 5. Metadata" >> "$MD"
echo "Snapshot Version: 2.1 (RAW)" >> "$MD"
echo "Mode: Rewrite" >> "$MD"
echo >> "$MD"

echo "✅ RAW snapshot saved to: ${MD/#$HOME/~}"
if command -v pbcopy >/dev/null 2>&1; then
  pbcopy < "$MD"
  echo "📋 Copied RAW snapshot to clipboard."
fi
