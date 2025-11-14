#!/usr/bin/env zsh
# MLS Auto-Record - Universal Activity Recorder
# Records ALL activities to MLS LEDGER (the actual working memory layer)
# 
# IMPORTANT: MLS Lessons (g/knowledge/mls_lessons.jsonl) wasn't being used in reality.
# That's why MLS LEDGER (mls/ledger/YYYY-MM-DD.jsonl) was created as the 2nd memory layer.
# THIS IS THE ACTUAL CORE BRAIN - everything must be recorded to the LEDGER.
set -euo pipefail

# Usage: mls_auto_record.zsh <activity_type> <title> <summary> [tags] [wo_id]
# Activity types: todo, pending, followup, reminder, failure, learning, lesson, deployment, debug, work, etc.

ACTIVITY_TYPE="${1:-}"
TITLE="${2:-}"
SUMMARY="${3:-}"
TAGS="${4:-}"
WO_ID="${5:-}"

if [[ -z "$ACTIVITY_TYPE" ]] || [[ -z "$TITLE" ]] || [[ -z "$SUMMARY" ]]; then
  cat <<USAGE
Usage: mls_auto_record.zsh <activity_type> <title> <summary> [tags] [wo_id]

Activity Types (MLS Core Brain Categories):
  todo        - Todo item created/completed
  pending     - Pending task
  followup    - Followup item
  reminder    - Reminder set
  failure     - Something failed (learn from it)
  learning    - Learning/insight gained
  lesson      - Lesson learned
  deployment  - Deployment performed
  debug       - Debugging session
  work        - General work activity
  solution    - Solution implemented
  improvement - System improvement
  pattern     - Pattern discovered
  antipattern - Anti-pattern to avoid

Examples:
  # Record a todo
  mls_auto_record.zsh todo "Fix CI bug" "Fixed GitHub Actions workflow" "ci,bug"

  # Record a deployment
  mls_auto_record.zsh deployment "Deploy v1.2.3" "Deployed new features" "deploy,production"

  # Record debugging
  mls_auto_record.zsh debug "Debug Redis connection" "Fixed connection timeout" "redis,debug"

  # Record learning
  mls_auto_record.zsh learning "Redis pub/sub pattern" "Learned about Redis channels" "redis,learning"

USAGE
  exit 1
fi

BASE="$HOME/02luka"
LEDGER_DIR="$BASE/mls/ledger"
mkdir -p "$LEDGER_DIR"

# Get current context
CURRENT_WO=$(ls -t ~/02luka/bridge/inbox/CLC/WO-*.{yaml,json,zsh} 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/\.[^.]*$//' || echo "")
CURRENT_SESSION=$(find ~/02luka/g/reports/sessions -name "*.md" -type f 2>/dev/null | sort -r | head -1 | xargs basename 2>/dev/null || echo "")
[[ -z "$WO_ID" ]] && WO_ID="$CURRENT_WO"

# Map activity type to MLS event type
case "$ACTIVITY_TYPE" in
  todo|pending|followup|reminder|work|deployment|debug)
    MLS_TYPE="improvement"
    ;;
  failure|antipattern)
    MLS_TYPE="failure"
    ;;
  learning|lesson|solution|pattern)
    MLS_TYPE="solution"
    ;;
  improvement)
    MLS_TYPE="improvement"
    ;;
  *)
    MLS_TYPE="improvement"  # Default
    ;;
esac

# Build tags
ALL_TAGS="$ACTIVITY_TYPE"
[[ -n "$TAGS" ]] && ALL_TAGS="${ALL_TAGS},${TAGS}"
[[ -n "$CURRENT_SESSION" && "$CURRENT_SESSION" != "none" ]] && ALL_TAGS="${ALL_TAGS},session"

  # Record to MLS LEDGER (the ACTUAL working memory layer - not lessons!)
  # This is the 2nd memory layer that was created because MLS lessons weren't being used
  if [[ -f "$BASE/tools/mls_add.zsh" ]]; then
  "$BASE/tools/mls_add.zsh" \
    --type "$MLS_TYPE" \
    --title "$TITLE" \
    --summary "$SUMMARY" \
    --producer "clc" \
    --context "local" \
    --repo "" \
    --run-id "" \
    --workflow "" \
    --sha "" \
    --artifact "" \
    --artifact-path "" \
    --followup-id "" \
    --wo-id "$WO_ID" \
    --tags "$ALL_TAGS" \
    --author "gg" \
    --confidence 0.9 2>/dev/null || {
    echo "⚠️  MLS recording failed (non-blocking)" >&2
    exit 0  # Non-blocking - don't fail the calling script
  }
  
    echo "✅ Recorded to MLS LEDGER: $ACTIVITY_TYPE - $TITLE"
else
  echo "⚠️  mls_add.zsh not found - activity not recorded to LEDGER" >&2
  exit 0  # Non-blocking
fi
