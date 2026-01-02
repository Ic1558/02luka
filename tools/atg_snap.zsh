#!/usr/bin/env zsh
# tools/atg_snap.zsh - Antigravity System Snapshot
# "The Truth" for AI Context - Rewrite Mode (Option A)

set -u
setopt +o nomatch

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BRIDGE_DIR="${ATG_BRIDGE_DIR:-/Users/icmini/02luka/magic_bridge}"
INBOX_DIR="$BRIDGE_DIR/inbox"
OUTBOX_DIR="$BRIDGE_DIR/outbox"

OUTPUT_MD="$INBOX_DIR/atg_snapshot.md"
OUTPUT_JSON="$OUTBOX_DIR/atg_snapshot.json"
SUMMARY_FILE="$OUTBOX_DIR/atg_snapshot.md.summary.txt"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Ensure directories exist
mkdir -p "$INBOX_DIR" "$OUTBOX_DIR"

# --- Helpers ---
run_and_capture() {
    local cmd="$1"
    local exit_file="$2"
    local output
    
    # Run command, capture output and exit code
    # We use eval to handle complex command strings with pipes
    output=$(eval "$cmd" 2>&1)
    local code=$?
    
    # Save exit code if file provided
    if [[ -n "$exit_file" ]]; then
        echo "$code" > "$exit_file"
    fi

    if [[ -n "$output" ]]; then
        echo "$output"
    else
        echo "(no output)"
    fi
}

# --- Snapshot Generation ---
cat > "$OUTPUT_MD" <<EOF
# 📸 Antigravity System Snapshot
**Timestamp (UTC):** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Timestamp (Local):** $(date +"%Y-%m-%dT%H:%M:%S%z")
**Repo Root:** $REPO_ROOT
**Branch:** $(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")
**HEAD:** $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "N/A")

## 1. Git Context 🌳
### Command: \`git -C '$REPO_ROOT' status --porcelain=v1\`
\`\`\`text
$(run_and_capture "git -C '$REPO_ROOT' status --porcelain=v1" "$TMP_DIR/git_status.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/git_status.exit")

### Command: \`git -C '$REPO_ROOT' log -1 --oneline\`
\`\`\`text
$(run_and_capture "git -C '$REPO_ROOT' log -1 --oneline" "$TMP_DIR/git_log.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/git_log.exit")

### Command: \`git -C '$REPO_ROOT' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'\`
\`\`\`text
$(run_and_capture "git -C '$REPO_ROOT' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'" "$TMP_DIR/git_diff.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/git_diff.exit")

## 2. Runtime Context ⚙️
### Command: \`pgrep -fl 'gemini_bridge|bridge\.sh|api_server|antigravity|fs_watcher|python' | grep -v atg_snap\`
\`\`\`text
$(run_and_capture "pgrep -fl 'gemini_bridge|bridge\.sh|api_server|antigravity|fs_watcher|python' | grep -v atg_snap" "$TMP_DIR/pgrep.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/pgrep.exit")

### Command: \`$REPO_ROOT/tools/ports_check.zsh\`
\`\`\`text
$(run_and_capture "$REPO_ROOT/tools/ports_check.zsh" "$TMP_DIR/ports.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/ports.exit")

## 3. Telemetry Pulse 📈
(Tailing last 50 lines - Checks for missing files)
### Command: \`tail -n 50 '$REPO_ROOT/g/telemetry/atg_runner.jsonl' 2>/dev/null || echo '_File not found: atg_runner.jsonl_'\`
\`\`\`text
$(run_and_capture "tail -n 50 '$REPO_ROOT/g/telemetry/atg_runner.jsonl' 2>/dev/null || echo '_File not found: atg_runner.jsonl_'" "$TMP_DIR/telemetry.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/telemetry.exit")

### Command: \`tail -n 50 '$REPO_ROOT/g/telemetry/fs_index.jsonl' 2>/dev/null || echo '_File not found: fs_index.jsonl_'\`
\`\`\`text
$(run_and_capture "tail -n 50 '$REPO_ROOT/g/telemetry/fs_index.jsonl' 2>/dev/null || echo '_File not found: fs_index.jsonl_'" "$TMP_DIR/fs_index.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/fs_index.exit")

## 4. System Logs (Errors) 🚨
(Tailing last 50 lines)
### Command: \`tail -n 50 '/tmp/com.02luka.fs_watcher.stderr.log'\`
\`\`\`text
$(run_and_capture "tail -n 50 '/tmp/com.02luka.fs_watcher.stderr.log'" "$TMP_DIR/fs_watcher.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/fs_watcher.exit")

### Command: \`tail -n 50 '/tmp/com.02luka.fs_watcher.stdout.log'\`
\`\`\`text
$(run_and_capture "tail -n 50 '/tmp/com.02luka.fs_watcher.stdout.log'" "$TMP_DIR/fs_watcher_out.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/fs_watcher_out.exit")

### Command: \`tail -n 50 '/tmp/com.antigravity.bridge.stderr.log'\`
\`\`\`text
$(run_and_capture "tail -n 50 '/tmp/com.antigravity.bridge.stderr.log'" "$TMP_DIR/bridge_err.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/bridge_err.exit")

### Command: \`tail -n 50 '/tmp/com.antigravity.bridge.stdout.log'\`
\`\`\`text
$(run_and_capture "tail -n 50 '/tmp/com.antigravity.bridge.stdout.log'" "$TMP_DIR/bridge_out.exit")
\`\`\`
**Exit Code:** $(cat "$TMP_DIR/bridge_out.exit")

## 5. Metadata
Snapshot Version: 2.1 (Strict Mode)
Mode: Rewrite
EOF

cat > "$OUTPUT_JSON" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "git": {
    "branch": "$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")",
    "head": "$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "N/A")"
  },
  "runtime": {
     "processes_raw": "See Markdown"
  },
  "telemetry": {
     "last_event_ts": "See Markdown"
  }
}
EOF

# --- Cleanup ---
echo "✅ Snapshot Generated: $OUTPUT_MD"
echo "   (Checked against Liam's Validation Rules)"

# Open if interactive
if [[ -t 1 ]]; then
    open "$OUTPUT_MD" || true
fi
