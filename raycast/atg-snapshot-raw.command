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

copy_to_clipboard() {
  command -v pbcopy >/dev/null 2>&1 || return 0
  pbcopy || true
}

out_file="$(mktemp -t atg_snapshot_raw.XXXXXX)"
trap 'rm -f "$out_file"' EXIT

{
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

  # 🔌 LAC STATUS (conditional: show only if running)
  if pgrep -fl "lac_manager" >/dev/null 2>&1; then
    echo "🔌 LAC STATUS"
    pgrep -fl "lac_manager" 2>/dev/null || true
    echo "Inbox: $(ls "$ROOT/bridge/inbox/lac" 2>/dev/null | wc -l | xargs) | Processing: $(ls "$ROOT/bridge/processing/LAC" 2>/dev/null | wc -l | xargs)"
    echo "--- lac_manager.log (tail 5) ---"
    tail -n 5 "$ROOT/g/logs/lac_manager.log" 2>/dev/null || echo "(log missing)"
    echo
  fi

  echo "TELEMETRY (last 20 lines)"
  echo "--- atg_runner.jsonl ---"
  tail -n 20 "$repo/g/telemetry/atg_runner.jsonl" 2>/dev/null || echo "(missing)"
  echo
  echo "--- decision_log.jsonl ---"
  tail -n 20 "$repo/g/telemetry/decision_log.jsonl" 2>/dev/null || echo "(missing)"
  echo

  echo "✅ RAW dump complete (no summarization)"
} > "$out_file"

copy_to_clipboard < "$out_file"

cat "$out_file"
echo "📋 Copied to clipboard"
exit 0
