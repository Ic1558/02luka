#!/usr/bin/env zsh
set -u

# Init
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AGENT="${GG_AGENT_ID:-${USER:-unknown}}"
REPO_ROOT=~/02luka
SNAPSHOT_EXIT="null"
SAVE_EXIT="null"
SNAPSHOT_ID="none"

cd "$REPO_ROOT" || exit 1

# Soft gate: Warn if attempting direct push to main (PR workflow preferred)
check_main_push_warning() {
  local current_branch=$(git branch --show-current 2>/dev/null || echo "")
  if [[ "$current_branch" == "main" ]]; then
    echo "⚠️  WARNING: You are on 'main' branch"
    echo "   Recommended: Use PR workflow instead of direct push"
    echo "   Policy: g/docs/PR_AUTOPILOT_RULES.md (main accepts changes via PR only)"
    echo ""
    echo "   If you proceed, ensure you have:"
    echo "   - ALLOW_PUSH_MAIN=1 (Boss override)"
    echo "   - Or use: git checkout -b feat/... && push branch && create PR"
    echo ""
  fi
}

# --- Step 0: Pre-Action Telemetry Read (GG Review requirement) ---
echo "📖 [0/3] Reading latest telemetry and session..."
echo ""

# Read latest telemetry files
if [[ -d "$REPO_ROOT/g/telemetry" ]]; then
  echo "📊 Recent telemetry:"
  for f in "$REPO_ROOT"/g/telemetry/*.jsonl(N.om[1,3]); do
    [[ -f "$f" ]] && echo "   $(basename "$f"): $(tail -n 1 "$f" 2>/dev/null | head -c 100)..."
  done
  echo ""
fi

# Read latest session summary
LATEST_SESSION=$(ls -t "$REPO_ROOT"/g/reports/sessions/*.ai.json 2>/dev/null | head -1)
if [[ -n "$LATEST_SESSION" ]]; then
  echo "📋 Latest session: $(basename "$LATEST_SESSION")"
  echo "   $(cat "$LATEST_SESSION" 2>/dev/null | head -c 200)..."
  echo ""
fi

# --- Step 1: Local Agent Review ---
echo "🔍 [1/3] Running Local Agent Review..."
# Run review. We use --quiet to reduce noise, but capture exit code.
# We assume staged changes by default as per standard dev workflow.
# If user didn't set LOCAL_REVIEW_ACK, this might fail.
if [[ -z "${LOCAL_REVIEW_ACK:-}" ]]; then
    echo "⚠️  LOCAL_REVIEW_ACK not set. Defaulting to --offline mode for safety."
    # Use array for zsh command execution
    REVIEW_CMD=(python3 tools/local_agent_review.py staged --quiet --offline)
else
    REVIEW_CMD=(python3 tools/local_agent_review.py staged --quiet)
fi

"${REVIEW_CMD[@]}"
REVIEW_EXIT=$?

if [[ $REVIEW_EXIT -gt 1 ]]; then
    echo "❌ Review encountered system/security error ($REVIEW_EXIT). Stopping chain."
    # We still log partial telemetry
else
    # --- Step 2: GitDrop Snapshot ---
    echo "📸 [2/3] Creating GitDrop Snapshot..."
    SNAPSHOT_LOG=$(python3 tools/gitdrop.py backup --reason "Auto-snapshot after review" 2>&1)
    SNAPSHOT_EXIT=$?
    
    # Extract Snapshot ID if created
    SNAPSHOT_ID=$(echo "$SNAPSHOT_LOG" | grep -o "Created snapshot [0-9_]*" | awk '{print $3}' || echo "none")
    if [[ "$SNAPSHOT_ID" == "none" ]]; then
         # Try to capture "No changes" message or similar
         SNAPSHOT_MSG=$(echo "$SNAPSHOT_LOG" | head -n 1)
    else
         SNAPSHOT_MSG="Created $SNAPSHOT_ID"
    fi
    echo "   → $SNAPSHOT_MSG"

    # --- Step 3: Save Session ---
    echo "💾 [3/3] Saving Session..."
    # Soft gate: Warn about PR workflow (but don't block)
    check_main_push_warning
    tools/save.sh "dev_review_chain"
    SAVE_EXIT=$?
fi

# --- Telemetry ---
TELEMETRY_FILE="g/telemetry/workflow_dev_review_save.jsonl"
mkdir -p g/telemetry

# Construct JSON manually
JSON_LOG="{\"ts\": \"$TIMESTAMP\", \"agent\": \"$AGENT\", \"review_exit\": $REVIEW_EXIT, \"snapshot_exit\": \"$SNAPSHOT_EXIT\", \"save_exit\": \"$SAVE_EXIT\"}"
echo "$JSON_LOG" >> "$TELEMETRY_FILE"

# --- Summary ---
echo ""
echo "=== Workflow Complete ==="
echo "✅ Review:   Exit $REVIEW_EXIT"
echo "✅ Snapshot: Exit $SNAPSHOT_EXIT ($SNAPSHOT_ID)"
echo "✅ Save:     Exit $SAVE_EXIT"
echo "📝 Telemetry logged to $TELEMETRY_FILE"

if [[ "$SAVE_EXIT" == "0" ]]; then
    exit 0
else
    exit 1
fi
