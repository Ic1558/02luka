#!/usr/bin/env zsh
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot
# @raycast.mode silent
# @raycast.packageName 02luka Antigravity
# @raycast.icon 📸
# @raycast.description Generate snapshot → wait summary → copy summary to clipboard
# @raycast.author 02luka
# @raycast.needsConfirmation false

set -euo pipefail

ROOT="$HOME/02luka"
INBOX="$ROOT/magic_bridge/inbox"
OUTBOX="$ROOT/magic_bridge/outbox"
PROCESSED="$ROOT/magic_bridge/processed"
HOTKEY_LOG="$ROOT/g/telemetry/raycast_atg_hotkey.log"

MD="$INBOX/atg_snapshot.md"
JSON="$INBOX/atg_snapshot.json"

# ---- config ----
FORMAT="md"          # md | json | both
WAIT_SEC=45          # how long to wait for Gemini Bridge summary
POLL_MS=250
# ----------------

mkdir -p "$INBOX" "$OUTBOX" "$PROCESSED" "$ROOT/g/telemetry"

# Log hotkey trigger (proof that Raycast executed this)
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Raycast hotkey triggered → atg-snapshot.command" >> "$HOTKEY_LOG"

# Generate snapshot file(s)
# Prefer the standalone snapshot generator if it exists inside this file's repo path,
# otherwise fall back to repo tools if present.
# We will invoke the existing snapshot logic by running the original script file (this file)
# only if user replaced it, so instead we implement minimal reliable snapshot here.

timestamp_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
timestamp_local="$(date +"%Y-%m-%dT%H:%M:%S%z")"
repo_root="$ROOT"

# helper: safe command capture
_run() {
  local cmd="$1"
  echo "### Command: \`$cmd\`" >> "$MD"
  echo '```text' >> "$MD"
  # shellcheck disable=SC2086
  eval "$cmd" >> "$MD" 2>&1 || true
  echo '```' >> "$MD"
  echo >> "$MD"
}

_write_md() {
  : > "$MD"
  {
    echo "# 📸 Antigravity System Snapshot"
    echo "**Timestamp (UTC):** $timestamp_utc"
    echo "**Timestamp (Local):** $timestamp_local"
    echo "**Repo Root:** $repo_root"
    if command -v git >/dev/null 2>&1; then
      echo "**Branch:** $(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
      echo "**HEAD:** $(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
    else
      echo "**Branch:** (git not found)"
      echo "**HEAD:** (git not found)"
    fi
    echo
    echo "## 1. Git Context 🌳"
  } >> "$MD"

  _run "git -C '$repo_root' status --porcelain=v1"
  _run "git -C '$repo_root' log -1 --oneline"
  _run "git -C '$repo_root' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'"

  {
    echo "## 2. Runtime Context ⚙️"
  } >> "$MD"
  _run "pgrep -fl 'gemini_bridge|bridge\\.sh|api_server|antigravity|fs_watcher|python' | grep -v atg_snap || true"

  {
    echo "## 3. Telemetry Pulse 📊"
    echo "(Tailing last 50 lines - Checks for missing files)"
  } >> "$MD"
  _run "tail -n 50 '$repo_root/g/telemetry/atg_runner.jsonl' 2>/dev/null || echo '_File not found: atg_runner.jsonl_'"
  _run "tail -n 50 '$repo_root/g/telemetry/fs_index.jsonl' 2>/dev/null || echo '_File not found: fs_index.jsonl_'"

  {
    echo "## 4. System Logs (Errors) 🔴"
    echo "(Tailing last 50 lines)"
  } >> "$MD"
  _run "tail -n 50 '/tmp/com.02luka.fs_watcher.stderr.log' 2>/dev/null || true"
  _run "tail -n 50 '/tmp/com.02luka.fs_watcher.stdout.log' 2>/dev/null || true"
  _run "tail -n 50 '/tmp/com.antigravity.bridge.stderr.log' 2>/dev/null || true"
  _run "tail -n 50 '/tmp/com.antigravity.bridge.stdout.log' 2>/dev/null || true"

  {
    echo "## 5. Metadata"
    echo "Snapshot Version: 2.1 (Strict Mode)"
    echo "Mode: Rewrite"
    echo
  } >> "$MD"
}

_write_json() {
  : > "$JSON"
  python3 - <<'PY' "$JSON" "$timestamp_utc" "$timestamp_local" "$repo_root"
import json, os, subprocess, sys
out, tsu, tsl, root = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def sh(cmd):
  try:
    p = subprocess.run(cmd, shell=True, cwd=root, capture_output=True, text=True)
    return {"cmd": cmd, "rc": p.returncode, "out": p.stdout, "err": p.stderr}
  except Exception as e:
    return {"cmd": cmd, "rc": 999, "out": "", "err": str(e)}

data = {
  "title": "Antigravity System Snapshot",
  "timestamp_utc": tsu,
  "timestamp_local": tsl,
  "repo_root": root,
  "git": {
    "status": sh("git -C '%s' status --porcelain=v1" % root),
    "log1": sh("git -C '%s' log -1 --oneline" % root),
    "diffstat": sh("git -C '%s' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'" % root),
  },
  "runtime": {
    "pgrep": sh("pgrep -fl 'gemini_bridge|bridge\\.sh|api_server|antigravity|fs_watcher|python' | grep -v atg_snap || true")
  },
  "telemetry": {
    "atg_runner_tail": sh("tail -n 50 '%s/g/telemetry/atg_runner.jsonl' 2>/dev/null || echo '_File not found: atg_runner.jsonl_'" % root),
    "fs_index_tail": sh("tail -n 50 '%s/g/telemetry/fs_index.jsonl' 2>/dev/null || echo '_File not found: fs_index.jsonl_'" % root),
  },
  "logs": {
    "fs_watcher_stderr": sh("tail -n 50 '/tmp/com.02luka.fs_watcher.stderr.log' 2>/dev/null || true"),
    "fs_watcher_stdout": sh("tail -n 50 '/tmp/com.02luka.fs_watcher.stdout.log' 2>/dev/null || true"),
    "bridge_stderr": sh("tail -n 50 '/tmp/com.antigravity.bridge.stderr.log' 2>/dev/null || true"),
    "bridge_stdout": sh("tail -n 50 '/tmp/com.antigravity.bridge.stdout.log' 2>/dev/null || true"),
  },
  "meta": {"version": "2.1", "mode": "rewrite"}
}
with open(out, "w", encoding="utf-8") as f:
  json.dump(data, f, ensure_ascii=False, indent=2)
PY
}

case "$FORMAT" in
  md)   _write_md ;;
  json) _write_json ;;
  both) _write_md; _write_json ;;
  *)    echo "❌ Invalid FORMAT=$FORMAT (use md|json|both)"; exit 1 ;;
esac

echo "✅ Snapshot saved to: ${MD/#$HOME/~}"
[[ -f "$JSON" ]] && echo "✅ Snapshot saved to: ${JSON/#$HOME/~}"
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Snapshot created: ${MD/#$HOME/~}" >> "$HOTKEY_LOG"

# Wait for summary produced by Gemini Bridge
summary_txt="$OUTBOX/atg_snapshot.md.summary.txt"
start="$(date +%s)"
while true; do
  if [[ -f "$summary_txt" ]]; then
    break
  fi
  now="$(date +%s)"
  if (( now - start >= WAIT_SEC )); then
    echo "⚠️ Summary not found within ${WAIT_SEC}s: ${summary_txt/#$HOME/~}"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Summary TIMEOUT after ${WAIT_SEC}s" >> "$HOTKEY_LOG"
    break
  fi
  /bin/sleep 0.25
done

# Copy summary to clipboard if present (preferred), else copy raw md
if [[ -f "$summary_txt" ]]; then
  elapsed=$(($(date +%s) - start))
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] Summary found in ${elapsed}s: ${summary_txt/#$HOME/~}" >> "$HOTKEY_LOG"
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$summary_txt"
    echo "📋 Copied SUMMARY to clipboard."
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ✅ SUMMARY copied to clipboard" >> "$HOTKEY_LOG"
  fi
else
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] Summary NOT found, using fallback" >> "$HOTKEY_LOG"
  if [[ -f "$MD" ]] && command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$MD"
    echo "📋 Copied RAW snapshot to clipboard (fallback)."
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ✅ RAW snapshot copied to clipboard (fallback)" >> "$HOTKEY_LOG"
  fi
fi

