#!/usr/bin/env zsh
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot
# @raycast.mode silent
# @raycast.packageName 02luka Antigravity
# @raycast.icon 🤯
# @raycast.description Capture repo/runtime/telemetry snapshot → drop to magic_bridge/inbox for AI summary.
# @raycast.needsConfirmation false

set -euo pipefail

ROOT="$HOME/02luka"
BRIDGE="$ROOT/magic_bridge"
INBOX="$BRIDGE/inbox"
mkdir -p "$INBOX"

repo="$ROOT"
out="$INBOX/atg_snapshot.md"

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
  echo "### Command: \`git -C '$repo' status --porcelain=v1\`"
  echo '```text'
  git -C "$repo" status --porcelain=v1 2>/dev/null || true
  echo '```'
  echo
  echo "### Command: \`git -C '$repo' log -1 --oneline\`"
  echo '```text'
  git -C "$repo" log -1 --oneline 2>/dev/null || true
  echo '```'
  echo
  echo "### Command: \`git -C '$repo' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'\`"
  echo '```text'
  (git -C "$repo" diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)') | sed -e 's/[[:space:]]\+$//'
  echo '```'
  echo
  echo "## 2. Runtime Context"
  echo "### Command: \`pgrep -fl 'gemini_bridge|bridge\\.sh|api_server|antigravity|fs_watcher|python' | grep -v atg_snap || true\`"
  echo '```text'
  (pgrep -fl "gemini_bridge|bridge\.sh|api_server|antigravity|fs_watcher|python" | grep -v atg_snap) 2>/dev/null || true
  echo '```'
  echo
  echo "## 3. Telemetry Pulse"
  echo "### Command: \`tail -n 50 '$repo/g/telemetry/atg_runner.jsonl'\`"
  echo '```text'
  tail -n 50 "$repo/g/telemetry/atg_runner.jsonl" 2>/dev/null || echo "_File not found: atg_runner.jsonl_"
  echo '```'
  echo
  echo "### Command: \`tail -n 50 '$repo/g/telemetry/fs_index.jsonl'\`"
  echo '```text'
  tail -n 50 "$repo/g/telemetry/fs_index.jsonl" 2>/dev/null || echo "_File not found: fs_index.jsonl_"
  echo '```'
  echo
  echo "## 4. System Logs (Errors)"
  echo "### Command: \`tail -n 50 '/tmp/com.02luka.fs_watcher.stderr.log'\`"
  echo '```text'
  tail -n 50 /tmp/com.02luka.fs_watcher.stderr.log 2>/dev/null || true
  echo '```'
  echo
  echo "### Command: \`tail -n 50 '/tmp/com.02luka.fs_watcher.stdout.log'\`"
  echo '```text'
  tail -n 50 /tmp/com.02luka.fs_watcher.stdout.log 2>/dev/null || true
  echo '```'
  echo
  echo "### Command: \`tail -n 50 '/tmp/com.antigravity.bridge.stderr.log'\`"
  echo '```text'
  tail -n 50 /tmp/com.antigravity.bridge.stderr.log 2>/dev/null || true
  echo '```'
  echo
  echo "### Command: \`tail -n 50 '/tmp/com.antigravity.bridge.stdout.log'\`"
  echo '```text'
  tail -n 50 /tmp/com.antigravity.bridge.stdout.log 2>/dev/null || true
  echo '```'
  echo
  echo "## 5. Metadata"
  echo "Snapshot Version: 2.2"
  echo "Mode: BridgeDrop"
} > "$tmp"

# atomic move (minimize watcher churn)
mv -f "$tmp" "$out"

# small stdout for Raycast "silent" mode
echo "OK: wrote $(basename "$out") → $INBOX"
