#!/usr/bin/env zsh
# Generate followup.json from real data sources:
# 1. Work Orders (WO) from g/followup/state/*.json (processed state files)
# 2. Local agent tasks from g/knowledge/tasks.jsonl
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
OUTPUT="$BASE/g/apps/dashboard/data/followup.json"
TEMP_FILE="${OUTPUT}.tmp"
STATE_DIR="$BASE/g/followup/state"

mkdir -p "$(dirname "$OUTPUT")"
mkdir -p "$STATE_DIR"

# Collect Work Orders from STATE FILES (not inbox)
collect_work_orders() {
  local items=()
  
  # Check if state directory exists
  if [[ ! -d "$STATE_DIR" ]]; then
    echo "[]"
    return
  fi
  
  # Find all state JSON files
  local state_files=()
  setopt null_glob
  for state_file in "$STATE_DIR"/*.json(.N); do
    [[ -f "$state_file" ]] && state_files+=("$state_file")
  done
  
  if [[ ${#state_files[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi
  
  for state_file in "${state_files[@]}"; do
    local wo_id=$(basename "$state_file" .json)
    
    # Read state JSON file
    if [[ ! -f "$state_file" ]]; then
      continue
    fi
    
    # Parse JSON state file
    local wo_data=$(cat "$state_file" 2>/dev/null || echo "")
    if [[ -z "$wo_data" ]]; then
      continue
    fi
    
    # Extract fields from state JSON using jq
    local title=$(echo "$wo_data" | jq -r '.title // .id // ""' 2>/dev/null || echo "")
    local description=$(echo "$wo_data" | jq -r '.description // .summary // ""' 2>/dev/null || echo "")
    local wo_status=$(echo "$wo_data" | jq -r '.status // "Open"' 2>/dev/null || echo "Open")
    local priority=$(echo "$wo_data" | jq -r '.priority // "Medium"' 2>/dev/null || echo "Medium")
    local due_date=$(echo "$wo_data" | jq -r '.due_date // .due // ""' 2>/dev/null || echo "")
    local goal=$(echo "$wo_data" | jq -r '.goal // ""' 2>/dev/null || echo "")
    local progress=$(echo "$wo_data" | jq -r '.progress // 0' 2>/dev/null || echo "0")
    local owner=$(echo "$wo_data" | jq -r '.owner // "Work Order System"' 2>/dev/null || echo "Work Order System")
    
    # Normalize status
    local normalized_status=""
    case "$wo_status" in
      Complete|completed|done|finished) normalized_status="Done" ;;
      InProgress|in_progress|processing|active) normalized_status="In Progress" ;;
      Paused|paused) normalized_status="Paused" ;;
      Open|open|pending) normalized_status="Open" ;;
      *) normalized_status="Open" ;;
    esac
    
    # Normalize priority
    case "$priority" in
      high|High|urgent|Urgent) priority="High" ;;
      medium|Medium|normal|Normal) priority="Medium" ;;
      low|Low) priority="Low" ;;
      *) priority="Medium" ;;
    esac
    
    # Ensure progress is numeric
    if ! [[ "$progress" =~ ^[0-9]+$ ]]; then
      progress="0"
    fi
    
    # Use WO ID as title fallback
    if [[ -z "$title" ]]; then
      title="$wo_id"
    fi
    
    # Create item JSON
    local item=$(jq -n \
      --arg id "$wo_id" \
      --arg title "$title" \
      --arg desc "${description:-Work Order: $wo_id}" \
      --arg status "$normalized_status" \
      --arg priority "$priority" \
      --arg due "${due_date:-}" \
      --arg goal "${goal:-}" \
      --arg progress "$progress" \
      --arg owner "$owner" \
      --arg source "work_order" \
      '{
        id: $id,
        title: $title,
        description: $desc,
        goal: $goal,
        progress: ($progress | tonumber),
        status: $status,
        priority: $priority,
        due_date: $due,
        owner: $owner,
        source: $source,
        tags: ["Work Order"],
        notes: ""
      }')
    
    items+=("$item")
  done
  
  # Output as JSON array
  if [[ ${#items[@]} -gt 0 ]]; then
    printf '%s\n' "${items[@]}" | jq -s '.'
  else
    echo "[]"
  fi
}

# Collect Agent Tasks
collect_agent_tasks() {
  local task_db="$BASE/g/knowledge/tasks.jsonl"
  local items=()
  
  if [[ ! -f "$task_db" ]]; then
    echo "[]"
    return
  fi
  
  # Read tasks.jsonl (handle both JSONL and pretty-printed JSON)
  local tasks_json=""
  if head -1 "$task_db" | jq . >/dev/null 2>&1; then
    # Pretty-printed JSON (single object or array)
    tasks_json=$(cat "$task_db" | jq -s 'if type == "array" then . else [.] end' 2>/dev/null || echo "[]")
  else
    # JSONL format
    tasks_json=$(cat "$task_db" | jq -s '.' 2>/dev/null || echo "[]")
  fi
  
  # Filter for followup, todo, pending, blocked types
  local filtered=$(echo "$tasks_json" | jq '[.[] | select(.type == "followup" or .type == "todo" or .type == "pending" or .type == "blocked")]')
  
  # Convert to followup format
  echo "$filtered" | jq -c '.[] | {
    id: .id,
    title: .title,
    description: .description // "",
    goal: .goal // .title,
    progress: (if .status == "done" then 100 elif .status == "in_progress" then 50 else 0 end),
    status: (if .status == "open" then "Open" elif .status == "in_progress" then "In Progress" elif .status == "done" then "Done" else "Open" end),
    priority: (if .priority == "high" then "High" elif .priority == "low" then "Low" else "Medium" end),
    due_date: .due_date // "",
    owner: .owner // "Local Agent",
    source: "agent_task",
    tags: (.tags // []),
    notes: (.notes // ""),
    related_wo: .related_wo // "",
    related_session: .related_session // ""
  }' | jq -s '.'
}

# Merge and format output
merge_data() {
  local wo_items="$1"
  local task_items="$2"
  
  # Merge arrays
  local merged=$(jq -s 'add' <<< "$wo_items"$'\n'"$task_items" 2>/dev/null || echo "[]")
  
  # Sort by priority (High > Medium > Low) then by due_date
  local sorted=$(echo "$merged" | jq 'sort_by([
    (.priority == "High" | not),
    (.priority == "Medium" | not),
    (.due_date // "9999-12-31")
  ])')
  
  # Create final output
  local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local owner="Operations Command Center"
  
  jq -n \
    --argjson items "$sorted" \
    --arg updated "$now" \
    --arg owner "$owner" \
    '{
      updated_at: $updated,
      owner: $owner,
      items: $items
    }'
}

# Main execution
main() {
  echo "📊 Collecting Work Orders..." >&2
  local wo_items=$(collect_work_orders)
  local wo_count=$(echo "$wo_items" | jq 'length')
  echo "   Found $wo_count work orders" >&2
  
  echo "📋 Collecting Agent Tasks..." >&2
  local task_items=$(collect_agent_tasks)
  local task_count=$(echo "$task_items" | jq 'length')
  echo "   Found $task_count agent tasks" >&2
  
  echo "🔄 Merging data..." >&2
  local merged=$(merge_data "$wo_items" "$task_items")
  
  # Atomic write
  echo "$merged" | jq . > "$TEMP_FILE"
  mv "$TEMP_FILE" "$OUTPUT"
  
  local total=$(echo "$merged" | jq '.items | length')
  echo "✅ Generated followup.json with $total items" >&2
  echo "   Output: $OUTPUT" >&2
}

main "$@"
