#!/usr/bin/env zsh
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot RAW
# @raycast.mode fullOutput
# @raycast.packageName 02luka
# @raycast.icon 📋
# @raycast.description Raw system dump (no transform)
# @raycast.needsConfirmation false

set -euo pipefail
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

ROOT="$HOME/02luka"
repo="$ROOT"

utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
head="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo '?')"

echo "🔍 RAW SYSTEM DUMP"
echo "Timestamp: $utc"
echo "Branch: $branch | HEAD: $head"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "📂 GIT STATUS (porcelain)"
git -C "$repo" status --porcelain=v1 2>/dev/null || echo "(git error)"
echo

echo "📝 LAST COMMIT"
git -C "$repo" log -1 --oneline 2>/dev/null || echo "(no commits)"
echo

echo "🔄 RECENT DIFF (HEAD~1)"
git -C "$repo" diff --stat HEAD~1 2>/dev/null | head -n 30 || echo "(no diff)"
echo

echo "🏃 RUNNING PROCESSES"
pgrep -fl "gemini_bridge|bridge\.sh|api_server|fs_watcher|mary|opal" 2>/dev/null || echo "(none)"
echo

echo "📊 TELEMETRY (last 20 lines)"
echo "--- atg_runner.jsonl ---"
tail -n 20 "$repo/g/telemetry/atg_runner.jsonl" 2>/dev/null || echo "(missing)"
echo
echo "--- decision_log.jsonl ---"
tail -n 20 "$repo/g/telemetry/decision_log.jsonl" 2>/dev/null || echo "(missing)"
echo

echo "✅ RAW dump complete (no summarization)"
exit 0
