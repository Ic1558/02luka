#!/usr/bin/env zsh
# Generate followup.json from real data sources:
# 1. Work Orders (WO) from bridge/inbox/
# 2. Local agent tasks from g/knowledge/tasks.jsonl
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
OUTPUT="$BASE/g/apps/dashboard/data/followup.json"
TEMP_FILE="${OUTPUT}.tmp"

mkdir -p "$(dirname "$OUTPUT")"

# Collect Work Orders
collect_work_orders() {
  local wo_dir="$BASE/bridge/inbox"
  local items=()
  
  # Find all WO files
  local wo_files=()
  if [[ -d "$wo_dir/CLC" ]]; then
    while IFS= read -r file; do
      [[ -f "$file" ]] && wo_files+=("$file")
    done < <(find "$wo_dir/CLC" -type f \( -name "WO-*.yaml" -o -name "WO-*.yml" -o -name "WO-*.zsh" -o -name "WO-*.md" \) 2>/dev/null | head -20)
  fi
  
  if [[ -d "$wo_dir/ENTRY" ]]; then
    while IFS= read -r file; do
      [[ -f "$file" ]] && wo_files+=("$file")
    done < <(find "$wo_dir/ENTRY" -type f \( -name "WO-*.yaml" -o -name "WO-*.yml" \) 2>/dev/null | head -10)
  fi
  
  for wo_file in "${wo_files[@]}"; do
    local wo_id=$(basename "$wo_file" | sed 's/\.[^.]*$//')
    local wo_data=""
    
    # Try to parse YAML
    if command -v yq >/dev/null 2>&1; then
      wo_data=$(yq eval '.' "$wo_file" 2>/dev/null || echo "")
    fi
    
    # Extract fields from YAML or filename
    local title=""
    local description=""
    local wo_status=""
    local priority=""
    local due_date=""
    local goal=""
    local progress=""
    
    if [[ -n "$wo_data" ]]; then
      title=$(echo "$wo_data" | yq eval '.title // .summary // .wo_id // ""' - 2>/dev/null || echo "")
      description=$(echo "$wo_data" | yq eval '.description // .intent // ""' - 2>/dev/null || echo "")
      wo_status=$(echo "$wo_data" | yq eval '.status // "active"' - 2>/dev/null || echo "active")
      priority=$(echo "$wo_data" | yq eval '.priority // "medium"' - 2>/dev/null || echo "medium")
      due_date=$(echo "$wo_data" | yq eval '.due_date // .deadline // ""' - 2>/dev/null || echo "")
      goal=$(echo "$wo_data" | yq eval '.goal // .deliverables[0] // ""' - 2>/dev/null || echo "")
      
      # Calculate progress if available
      if echo "$wo_data" | yq eval '.progress // .completion_percentage // null' - 2>/dev/null | grep -q '[0-9]'; then
        progress=$(echo "$wo_data" | yq eval '.progress // .completion_percentage' - 2>/dev/null || echo "0")
      else
        # Estimate progress from status
        case "$wo_status" in
          completed|done) progress="100" ;;
          in_progress|active) progress="50" ;;
          pending|open) progress="0" ;;
          *) progress="0" ;;
        esac
      fi
    else
      # Fallback: use filename
      title="$wo_id"
      description="Work Order: $wo_id"
      wo_status="active"
      priority="medium"
    fi
    
    # Normalize status
    local normalized_status=""
    case "$wo_status" in
      active|open|pending) normalized_status="Open" ;;
      in_progress|processing) normalized_status="In Progress" ;;
      completed|done|finished) normalized_status="Done" ;;
      *) normalized_status="Open" ;;
    esac
    
    # Normalize priority
    case "$priority" in
      high|urgent) priority="High" ;;
      medium|normal) priority="Medium" ;;
      low) priority="Low" ;;
      *) priority="Medium" ;;
    esac
    
    # Create item JSON
    local item=$(jq -n \
      --arg id "$wo_id" \
      --arg title "${title:-$wo_id}" \
      --arg desc "${description:-Work Order}" \
      --arg status "$normalized_status" \
      --arg priority "$priority" \
      --arg due "${due_date:-}" \
      --arg goal "${goal:-}" \
      --arg progress "${progress:-0}" \
      --arg owner "Work Order System" \
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
