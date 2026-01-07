#!/usr/bin/env zsh
# ATG System Snapshot Generator
# Captures comprehensive system state for debugging and AI context

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

TIMESTAMP_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_LOCAL=$(date +"%Y-%m-%dT%H:%M:%S%z")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

FORMAT="${1:-md}"
OUTPUT_DIR="magic_bridge/inbox"
OUTPUT_FILE="$OUTPUT_DIR/atg_snapshot"

mkdir -p "$OUTPUT_DIR"

# Generate Markdown snapshot
generate_md() {
  cat <<EOF
# 📸 Antigravity System Snapshot
**Timestamp (UTC):** $TIMESTAMP_UTC
**Timestamp (Local):** $TIMESTAMP_LOCAL
**Repo Root:** $ROOT
**Branch:** $BRANCH
**HEAD:** $HEAD

## 1. Git Context 🌳
### Command: \`git -C '$ROOT' status --porcelain=v1\`
\`\`\`text
$(git -C "$ROOT" status --porcelain=v1 2>&1 || echo "(error)")
\`\`\`
**Exit Code:** $?

### Command: \`git -C '$ROOT' log -1 --oneline\`
\`\`\`text
$(git -C "$ROOT" log -1 --oneline 2>&1 || echo "(error)")
\`\`\`
**Exit Code:** $?

### Command: \`git -C '$ROOT' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'\`
\`\`\`text
$(git -C "$ROOT" diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)')
\`\`\`
**Exit Code:** $?

## 2. Runtime Context ⚙️
### Command: \`pgrep -fl 'gemini_bridge|bridge\.sh|api_server|antigravity|fs_watcher|python' | grep -v atg_snap\`
\`\`\`text
$(pgrep -fl 'gemini_bridge|bridge\.sh|api_server|antigravity|fs_watcher|python' 2>&1 | grep -v atg_snap || echo "(no processes found)")
\`\`\`
**Exit Code:** $?

### Command: \`$ROOT/tools/ports_check.zsh\`
\`\`\`text
$(if [[ -x "$ROOT/tools/ports_check.zsh" ]]; then "$ROOT/tools/ports_check.zsh" 2>&1 || echo "(error)"; else echo "(ports_check.zsh not found)"; fi)
\`\`\`
**Exit Code:** $?

## 3. Telemetry Pulse 📊
(Tailing last 50 lines - Checks for missing files)
### Command: \`tail -n 50 '$ROOT/g/telemetry/atg_runner.jsonl' 2>/dev/null || echo '_File not found: atg_runner.jsonl_'\`
\`\`\`text
$(tail -n 50 "$ROOT/g/telemetry/atg_runner.jsonl" 2>/dev/null || echo "_File not found: atg_runner.jsonl_")
\`\`\`
**Exit Code:** $?

### Command: \`tail -n 50 '$ROOT/g/telemetry/fs_index.jsonl' 2>/dev/null || echo '_File not found: fs_index.jsonl_'\`
\`\`\`text
$(tail -n 50 "$ROOT/g/telemetry/fs_index.jsonl" 2>/dev/null || echo "_File not found: fs_index.jsonl_")
\`\`\`
**Exit Code:** $?

## 4. System Logs (Errors) 🔴
(Tailing last 50 lines)
### Command: \`tail -n 50 '/tmp/com.02luka.fs_watcher.stderr.log'\`
\`\`\`text
$(tail -n 50 /tmp/com.02luka.fs_watcher.stderr.log 2>/dev/null || echo "(no log file)")
\`\`\`
**Exit Code:** $?

### Command: \`tail -n 50 '/tmp/com.02luka.fs_watcher.stdout.log'\`
\`\`\`text
$(tail -n 50 /tmp/com.02luka.fs_watcher.stdout.log 2>/dev/null || echo "(no log file)")
\`\`\`
**Exit Code:** $?

### Command: \`tail -n 50 '/tmp/com.antigravity.bridge.stderr.log'\`
\`\`\`text
$(tail -n 50 /tmp/com.antigravity.bridge.stderr.log 2>/dev/null || echo "(no log file)")
\`\`\`
**Exit Code:** $?

### Command: \`tail -n 50 '/tmp/com.antigravity.bridge.stdout.log'\`
\`\`\`text
$(tail -n 50 /tmp/com.antigravity.bridge.stdout.log 2>/dev/null || echo "(no log file)")
\`\`\`
**Exit Code:** $?

## 5. Metadata
Snapshot Version: 2.1 (Strict Mode)
Mode: Rewrite

EOF
}

# Generate JSON snapshot
generate_json() {
  cat <<EOF
{
  "timestamp_utc": "$TIMESTAMP_UTC",
  "timestamp_local": "$TIMESTAMP_LOCAL",
  "repo_root": "$ROOT",
  "branch": "$BRANCH",
  "head": "$HEAD",
  "git": {
    "status": $(git -C "$ROOT" status --porcelain=v1 2>&1 | jq -Rs . || echo '""'),
    "last_commit": $(git -C "$ROOT" log -1 --oneline 2>&1 | jq -Rs . || echo '""'),
    "diff_stat": $(git -C "$ROOT" diff --stat HEAD~1 2>/dev/null | jq -Rs . || echo '"(Initial commit or no parent)"')
  },
  "runtime": {
    "processes": $(pgrep -fl 'gemini_bridge|bridge\.sh|api_server|antigravity|fs_watcher|python' 2>&1 | grep -v atg_snap | jq -Rs . || echo '""')
  },
  "version": "2.1"
}
EOF
}

case "$FORMAT" in
  json)
    generate_json > "${OUTPUT_FILE}.json"
    echo "✅ JSON snapshot: ${OUTPUT_FILE}.json"
    ;;
  both)
    generate_md > "${OUTPUT_FILE}.md"
    generate_json > "${OUTPUT_FILE}.json"
    echo "✅ MD snapshot: ${OUTPUT_FILE}.md"
    echo "✅ JSON snapshot: ${OUTPUT_FILE}.json"
    ;;
  *)
    generate_md > "${OUTPUT_FILE}.md"
    echo "✅ Snapshot: ${OUTPUT_FILE}.md"
    ;;
esac
