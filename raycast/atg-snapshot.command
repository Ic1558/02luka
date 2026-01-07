#!/usr/bin/env zsh
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot
# @raycast.mode silent
# @raycast.packageName 02luka Antigravity
# @raycast.description Generate snapshot → drop to magic_bridge/inbox → copy summary to clipboard (auto-run)
# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "mode (auto/full)", "optional": true }
# @raycast.icon 🤯

set -euo pipefail

MODE="${1:-auto}"   # IMPORTANT: default to auto so hotkey runs without prompting
REPO="$HOME/02luka"
BRIDGE="$REPO/magic_bridge"
INBOX="$BRIDGE/inbox"
OUTBOX="$BRIDGE/outbox"

mkdir -p "$INBOX" "$OUTBOX"

ts_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ts_local="$(date +%Y-%m-%dT%H:%M:%S%z)"
host="$(scutil --get LocalHostName 2>/dev/null || hostname)"
branch="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
headrev="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo '-')"

OUT_MD="$INBOX/atg_snapshot.md"
OUT_JSON="$INBOX/atg_snapshot.json"
SUM_TXT="$OUTBOX/atg_snapshot.md.summary.txt"

# --- Build RAW snapshot (markdown) ---
{
  echo "# 🤯 Antigravity System Snapshot (RAW)"
  echo "**Timestamp (UTC):** $ts_utc"
  echo "**Timestamp (Local):** $ts_local"
  echo "**Host:** $host"
  echo "**Repo Root:** $REPO"
  echo "**Branch:** $branch"
  echo "**HEAD:** $headrev"
  echo
  echo "## 1. Git Context 🧾"
  echo "### Command: \`git -C '$REPO' status --porcelain=v1\`"
  echo '```text'
  git -C "$REPO" status --porcelain=v1 2>/dev/null || true
  echo '```'
  echo
  echo "### Command: \`git -C '$REPO' log -1 --oneline\`"
  echo '```text'
  git -C "$REPO" log -1 --oneline 2>/dev/null || true
  echo '```'
  echo
  echo "### Command: \`git -C '$REPO' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'\`"
  echo '```text'
  (git -C "$REPO" diff --stat HEAD~1 2>/dev/null) || echo "(Initial commit or no parent)"
  echo '```'
  echo
  echo "## 2. Runtime Context ⚙️"
  echo "### Command: \`pgrep -fl 'Antigravity|antigravity|codex|gemini_bridge|fs_watcher|api_server|claude-proxy|language_server' | head -n 80\`"
  echo '```text'
  (pgrep -fl 'Antigravity|antigravity|codex|gemini_bridge|fs_watcher|api_server|claude-proxy|language_server' 2>/dev/null | head -n 80) || true
  echo '```'
  echo
  echo "## 3. Antigravity Signals 🧠"
  echo "### Recent Antigravity app logs (best-effort)"
  echo '```text'
  # Common log locations (best-effort; ignore if missing)
  for p in \
    "$HOME/Library/Logs/Antigravity" \
    "$HOME/Library/Logs/Antigravity/Antigravity.log" \
    "$HOME/Library/Logs/Antigravity/antigravity.log" \
    "$HOME/Library/Logs/Antigravity Helper" \
    "$HOME/Library/Logs/Google/Antigravity" \
    "$HOME/.antigravity" \
    ; do
    if [[ -d "$p" ]]; then
      echo "== dir: $p =="
      ls -lt "$p" 2>/dev/null | head -n 20 || true
    elif [[ -f "$p" ]]; then
      echo "== tail: $p =="
      tail -n 60 "$p" 2>/dev/null || true
    fi
  done
  echo '```'
  echo
  echo "## 4. Telemetry Pulse 📈"
  echo "### Command: \`tail -n 60 '$REPO/g/telemetry/atg_runner.jsonl'\`"
  echo '```text'
  tail -n 60 "$REPO/g/telemetry/atg_runner.jsonl" 2>/dev/null || echo "_File not found: atg_runner.jsonl_"
  echo '```'
  echo
  echo "## 5. Metadata"
  echo "Snapshot Version: 3.0 (RAW)"
  echo "Mode: $MODE"
} > "$OUT_MD"

# --- Build small JSON snapshot too (machine parseable) ---
python3 - <<PY 2>/dev/null || true
import json, os, subprocess, datetime
repo=os.path.expanduser("~/02luka")
def sh(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        return ""
data={
  "ts_utc": datetime.datetime.utcnow().isoformat()+"Z",
  "repo": repo,
  "branch": sh(["git","-C",repo,"rev-parse","--abbrev-ref","HEAD"]),
  "head": sh(["git","-C",repo,"rev-parse","--short","HEAD"]),
  "git_status": sh(["git","-C",repo,"status","--porcelain=v1"]),
}
out=os.path.expanduser("~/02luka/magic_bridge/inbox/atg_snapshot.json")
with open(out,"w",encoding="utf-8") as f:
    json.dump(data,f,ensure_ascii=False,indent=2)
PY

# Ensure file event ticks (some watchers rely on mtime change)
touch "$OUT_MD" "$OUT_JSON" 2>/dev/null || true

# --- AUTO behavior: wait briefly for summary then copy to clipboard ---
if [[ "$MODE" == "full" ]]; then
  pbcopy < "$OUT_MD" || true
  echo "✅ RAW snapshot copied to clipboard."
  echo "RAW: $OUT_MD"
  exit 0
fi

# mode=auto: wait for summary file to appear
deadline=$((SECONDS + 15))
while [[ $SECONDS -lt $deadline ]]; do
  if [[ -f "$SUM_TXT" ]]; then
    pbcopy < "$SUM_TXT" || true
    echo "✅ Summary copied to clipboard."
    echo "SUMMARY: $SUM_TXT"
    exit 0
  fi
  sleep 0.25
done

echo "🟨 Snapshot dropped, waiting summary timed out (bridge may be busy)."
echo "RAW: $OUT_MD"
echo "Expected summary: $SUM_TXT"
