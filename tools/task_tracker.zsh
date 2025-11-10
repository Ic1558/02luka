#!/usr/bin/env zsh
# Task Tracker - Todo, Pending, Followup, Blocked task management
# Separate from MLS (lessons) but can optionally link to MLS for context
set -euo pipefail

TASK_DB="$HOME/02luka/g/knowledge/tasks.jsonl"
TASK_INDEX="$HOME/02luka/g/knowledge/tasks_index.json"
mkdir -p "$(dirname "$TASK_DB")"

# Usage: task_tracker.zsh <command> <type> <title> [options]
# Commands: add, update, list, complete, cancel, link-mls

COMMAND="${1:-}"
shift || true

show_usage() {
  cat <<USAGE
Usage: task_tracker.zsh <command> [args]

Commands:
  add <type> <title> <description> [priority] [due_date] [owner]
      Add a new task
      Types: todo, pending, followup, blocked
      Priority: high, medium, low (default: medium)

  update <task_id> <field> <value>
      Update a task field (status, priority, notes, etc.)

  complete <task_id> [create_mls_lesson]
      Mark task as done. Optional: create MLS lesson (yes/no)

  cancel <task_id> [reason]
      Cancel a task with optional reason

  link-mls <task_id> <mls_lesson_id>
      Link task to MLS lesson for more context

  list [status] [type]
      List tasks (filter by status and/or type)
      Status: open, in_progress, done, cancelled, all (default: open)

  show <task_id>
      Show detailed task information

Examples:
  # Add a todo
  task_tracker.zsh add todo "Fix CI pipeline" "GitHub Actions failing on main" high 2025-11-15 CLC

  # Add a followup
  task_tracker.zsh add followup "Review MLS stats" "Check monthly learning patterns" medium

  # Update task status
  task_tracker.zsh update TASK-1762710000 status in_progress

  # Complete task and create MLS lesson
  task_tracker.zsh complete TASK-1762710000 yes

  # Link to MLS for context
  task_tracker.zsh link-mls TASK-1762710000 MLS-1762709136

  # List all open tasks
  task_tracker.zsh list

  # List all done followups
  task_tracker.zsh list done followup

USAGE
}

if [[ -z "$COMMAND" ]]; then
  show_usage
  exit 1
fi

# Initialize index if not exists
init_index() {
  if [[ ! -f "$TASK_INDEX" ]]; then
    echo '{"total":0,"by_type":{},"by_status":{},"last_updated":""}' > "$TASK_INDEX"
  fi
}

# Update index
update_index() {
  if [[ ! -f "$TASK_DB" ]]; then
    init_index
    return
  fi

  INDEX=$(jq -s '{
    total: length,
    by_type: (group_by(.type) | map({(.[0].type): length}) | add),
    by_status: (group_by(.status) | map({(.[0].status): length}) | add),
    last_updated: (map(.updated_at) | max)
  }' "$TASK_DB")

  echo "$INDEX" > "$TASK_INDEX"
}

# Get current context
get_context() {
  CURRENT_WO=$(ls -t ~/02luka/bridge/inbox/CLC/WO-*.{zsh,json} 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "none")
  CURRENT_SESSION=$(ls -t ~/02luka/memory/clc/session_*.md 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "none")
}

case "$COMMAND" in
  add)
    TYPE="${1:-}"
    TITLE="${2:-}"
    DESC="${3:-}"
    PRIORITY="${4:-medium}"
    DUE_DATE="${5:-}"
    OWNER="${6:-CLC}"

    if [[ -z "$TYPE" ]] || [[ -z "$TITLE" ]] || [[ -z "$DESC" ]]; then
      echo "❌ Error: type, title, and description are required"
      show_usage
      exit 1
    fi

    # Validate type
    if [[ ! "$TYPE" =~ ^(todo|pending|followup|blocked)$ ]]; then
      echo "❌ Error: Invalid type '$TYPE'. Must be: todo, pending, followup, or blocked"
      exit 1
    fi

    # Validate priority
    if [[ ! "$PRIORITY" =~ ^(high|medium|low)$ ]]; then
      echo "⚠️  Warning: Invalid priority '$PRIORITY'. Using 'medium'"
      PRIORITY="medium"
    fi

    TIMESTAMP=$(date +%s)
    TASK_ID="TASK-${TIMESTAMP}"
    get_context

    TASK=$(jq -n \
      --arg id "$TASK_ID" \
      --arg type "$TYPE" \
      --arg title "$TITLE" \
      --arg desc "$DESC" \
      --arg priority "$PRIORITY" \
      --arg due_date "$DUE_DATE" \
      --arg owner "$OWNER" \
      --arg wo "$CURRENT_WO" \
      --arg session "$CURRENT_SESSION" \
      --arg created "$(date -Iseconds)" \
      '{
        id: $id,
        type: $type,
        title: $title,
        description: $desc,
        status: "open",
        priority: $priority,
        due_date: $due_date,
        owner: $owner,
        tags: [],
        notes: "",
        related_wo: $wo,
        related_session: $session,
        mls_lesson_id: null,
        created_at: $created,
        updated_at: $created,
        completed_at: null
      }')

    echo "$TASK" >> "$TASK_DB"
    update_index

    echo "✅ Task created: $TASK_ID"
    echo "   Type: $TYPE | Priority: $PRIORITY"
    echo "   Title: $TITLE"
    [[ -n "$DUE_DATE" ]] && echo "   Due: $DUE_DATE"
    echo ""
    echo "📊 Task Stats:"
    cat "$TASK_INDEX" | jq -r '
      "   Total tasks: \(.total)",
      "   By type: \(.by_type | to_entries | map("\(.key)=\(.value)") | join(", "))",
      "   By status: \(.by_status | to_entries | map("\(.key)=\(.value)") | join(", "))"
    '
    ;;

  update)
    TASK_ID="${1:-}"
    FIELD="${2:-}"
    VALUE="${3:-}"

    if [[ -z "$TASK_ID" ]] || [[ -z "$FIELD" ]] || [[ -z "$VALUE" ]]; then
      echo "❌ Error: task_id, field, and value are required"
      show_usage
      exit 1
    fi

    if [[ ! -f "$TASK_DB" ]]; then
      echo "❌ Error: No tasks found"
      exit 1
    fi

    # Update the task
    TEMP_FILE=$(mktemp)
    jq --arg id "$TASK_ID" \
       --arg field "$FIELD" \
       --arg value "$VALUE" \
       --arg updated "$(date -Iseconds)" \
       'if .id == $id then .[$field] = $value | .updated_at = $updated else . end' \
       "$TASK_DB" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$TASK_DB"
    update_index

    echo "✅ Updated task $TASK_ID"
    echo "   $FIELD: $VALUE"
    ;;

  complete)
    TASK_ID="${1:-}"
    CREATE_MLS="${2:-no}"

    if [[ -z "$TASK_ID" ]]; then
      echo "❌ Error: task_id is required"
      show_usage
      exit 1
    fi

    if [[ ! -f "$TASK_DB" ]]; then
      echo "❌ Error: No tasks found"
      exit 1
    fi

    # Mark as done
    COMPLETED=$(date -Iseconds)
    TEMP_FILE=$(mktemp)
    jq --arg id "$TASK_ID" \
       --arg completed "$COMPLETED" \
       'if .id == $id then .status = "done" | .completed_at = $completed | .updated_at = $completed else . end' \
       "$TASK_DB" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$TASK_DB"
    update_index

    echo "✅ Task completed: $TASK_ID"

    # Optional: Create MLS lesson
    if [[ "$CREATE_MLS" == "yes" ]] || [[ "$CREATE_MLS" == "y" ]]; then
      TASK_DATA=$(cat "$TASK_DB" | jq -r --arg id "$TASK_ID" 'select(.id == $id)')
      TITLE=$(echo "$TASK_DATA" | jq -r '.title')
      DESC=$(echo "$TASK_DATA" | jq -r '.description')

      echo ""
      echo "📚 Creating MLS lesson from completed task..."
      ~/02luka/tools/mls_capture.zsh solution "$TITLE" "$DESC" "Completed task: $TASK_ID"

      # Link MLS to task
      MLS_ID=$(ls -t ~/02luka/g/knowledge/mls_lessons.jsonl | head -1 | jq -r '.id' 2>/dev/null || echo "")
      if [[ -n "$MLS_ID" ]]; then
        TEMP_FILE2=$(mktemp)
        jq --arg id "$TASK_ID" \
           --arg mls "$MLS_ID" \
           'if .id == $id then .mls_lesson_id = $mls else . end' \
           "$TASK_DB" > "$TEMP_FILE2"
        mv "$TEMP_FILE2" "$TASK_DB"
        echo "🔗 Linked to MLS: $MLS_ID"
      fi
    fi
    ;;

  cancel)
    TASK_ID="${1:-}"
    REASON="${2:-Cancelled by user}"

    if [[ -z "$TASK_ID" ]]; then
      echo "❌ Error: task_id is required"
      show_usage
      exit 1
    fi

    if [[ ! -f "$TASK_DB" ]]; then
      echo "❌ Error: No tasks found"
      exit 1
    fi

    CANCELLED=$(date -Iseconds)
    TEMP_FILE=$(mktemp)
    jq --arg id "$TASK_ID" \
       --arg reason "$REASON" \
       --arg cancelled "$CANCELLED" \
       'if .id == $id then .status = "cancelled" | .notes = ($reason + " | " + .notes) | .updated_at = $cancelled else . end' \
       "$TASK_DB" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$TASK_DB"
    update_index

    echo "✅ Task cancelled: $TASK_ID"
    echo "   Reason: $REASON"
    ;;

  link-mls)
    TASK_ID="${1:-}"
    MLS_ID="${2:-}"

    if [[ -z "$TASK_ID" ]] || [[ -z "$MLS_ID" ]]; then
      echo "❌ Error: task_id and mls_lesson_id are required"
      show_usage
      exit 1
    fi

    if [[ ! -f "$TASK_DB" ]]; then
      echo "❌ Error: No tasks found"
      exit 1
    fi

    TEMP_FILE=$(mktemp)
    jq --arg id "$TASK_ID" \
       --arg mls "$MLS_ID" \
       'if .id == $id then .mls_lesson_id = $mls else . end' \
       "$TASK_DB" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$TASK_DB"

    echo "✅ Linked task $TASK_ID to MLS lesson $MLS_ID"
    ;;

  list)
    STATUS="${1:-open}"
    TYPE="${2:-}"

    if [[ ! -f "$TASK_DB" ]]; then
      echo "📋 No tasks found"
      exit 0
    fi

    echo "📋 Tasks:"
    echo ""

    cat "$TASK_DB" | jq -r \
      --arg status "$STATUS" \
      --arg type "$TYPE" \
      'select(
        ($status == "all" or .status == $status) and
        ($type == "" or .type == $type)
      ) |
      [.id, .type, .priority, .status, .title, .due_date] |
      @tsv' | \
      column -t -s $'\t' -N "ID,TYPE,PRI,STATUS,TITLE,DUE"

    echo ""
    cat "$TASK_INDEX" | jq -r '
      "📊 Summary:",
      "   Total: \(.total)",
      "   By type: \(.by_type | to_entries | map("\(.key)=\(.value)") | join(", "))",
      "   By status: \(.by_status | to_entries | map("\(.key)=\(.value)") | join(", "))"
    '
    ;;

  show)
    TASK_ID="${1:-}"

    if [[ -z "$TASK_ID" ]]; then
      echo "❌ Error: task_id is required"
      show_usage
      exit 1
    fi

    if [[ ! -f "$TASK_DB" ]]; then
      echo "❌ Error: No tasks found"
      exit 1
    fi

    cat "$TASK_DB" | jq --arg id "$TASK_ID" 'select(.id == $id)'
    ;;

  *)
    echo "❌ Error: Unknown command '$COMMAND'"
    show_usage
    exit 1
    ;;
esac
