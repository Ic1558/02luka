#!/usr/bin/env zsh
# MLS (Machine Learning System) - Capture Lessons Learned
# Auto-triggered after system improvements, solutions, or failures
set -euo pipefail

# SOT variable (PATH protocol compliance)
SOT="${SOT:-$HOME/02luka}"

MLS_DB="$SOT/g/knowledge/mls_lessons.jsonl"
MLS_INDEX="$SOT/g/knowledge/mls_index.json"
mkdir -p "$(dirname "$MLS_DB")"

# Usage: mls_capture.zsh <type> <title> <description> [context]
# Types: solution, failure, improvement, pattern, antipattern

TYPE="${1:-}"
TITLE="${2:-}"
DESC="${3:-}"
CONTEXT="${4:-}"

if [[ -z "$TYPE" ]] || [[ -z "$TITLE" ]] || [[ -z "$DESC" ]]; then
  cat <<USAGE
Usage: mls_capture.zsh <type> <title> <description> [context]

Types:
  solution     - Something that worked well
  failure      - Something that failed (learn from it)
  improvement  - System enhancement made
  pattern      - Successful pattern discovered
  antipattern  - Anti-pattern to avoid

Examples:
  mls_capture.zsh solution "GD Sync Setup" "Two-phase automated deployment worked perfectly" "Phase1+Phase2 with conflict resolution"

  mls_capture.zsh failure "Direct GD Merge" "Merging 89GB+6.5GB GD folders was too complex" "Different structures, chose fresh start instead"

  mls_capture.zsh pattern "Archive with README" "Always create README when archiving large files" "89GB diagnostics with 60-day review plan"

USAGE
  exit 1
fi

# Generate lesson ID
TIMESTAMP=$(date +%s)
LESSON_ID="MLS-${TIMESTAMP}"

# Capture current context
CURRENT_WO=$(ls -t "$SOT/bridge/inbox/CLC/WO-*.zsh" 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "none")
CURRENT_SESSION=$(ls -t "$SOT/g/reports/sessions/*.md" 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "none")

# Create lesson entry
LESSON=$(jq -n \
  --arg id "$LESSON_ID" \
  --arg type "$TYPE" \
  --arg title "$TITLE" \
  --arg desc "$DESC" \
  --arg context "$CONTEXT" \
  --arg wo "$CURRENT_WO" \
  --arg session "$CURRENT_SESSION" \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    id: $id,
    type: $type,
    title: $title,
    description: $desc,
    context: $context,
    related_wo: $wo,
    related_session: $session,
    timestamp: $ts,
    tags: [],
    verified: false,
    usefulness_score: 0
  }')

# Append to database
echo "$LESSON" >> "$MLS_DB"

# Update index
if [[ -f "$MLS_INDEX" ]]; then
  INDEX=$(cat "$MLS_INDEX")
else
  INDEX='{"total":0,"by_type":{},"last_updated":""}'
fi

# Increment counts
NEW_INDEX=$(echo "$INDEX" | jq \
  --arg type "$TYPE" \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '.total += 1 | .by_type[$type] = (.by_type[$type] // 0) + 1 | .last_updated = $ts')

echo "$NEW_INDEX" > "$MLS_INDEX"

# Output
echo "✅ Lesson captured: $LESSON_ID"
echo "   Type: $TYPE"
echo "   Title: $TITLE"
echo ""
echo "📊 MLS Stats:"
echo "$NEW_INDEX" | jq -r '
  "   Total lessons: \(.total)",
  "   By type:",
  (.by_type | to_entries[] | "     - \(.key): \(.value)")
'

# Trigger R&D autopilot notification
if [[ -d "$SOT/bridge/inbox/RD" ]]; then
  RD_NOTIFICATION="$SOT/bridge/inbox/RD/MLS-notification-${TIMESTAMP}.json"
  jq -n \
    --arg lesson_id "$LESSON_ID" \
    --arg type "$TYPE" \
    --arg title "$TITLE" \
    '{
      task: "review_mls_lesson",
      lesson_id: $lesson_id,
      lesson_type: $type,
      title: $title,
      priority: "P3",
      auto_approve: true
    }' > "$RD_NOTIFICATION"

  echo "🔔 Notified R&D autopilot"
fi

echo ""
echo "📚 View all lessons:"
echo "   cat $MLS_DB | jq"
echo ""
echo "🔍 Search lessons:"
echo "   \$SOT/tools/mls_search.zsh <keyword>"
