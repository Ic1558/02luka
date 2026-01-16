#!/usr/bin/env zsh
set -euo pipefail

# Bridge Self-Check Tool
# Scans bridge/inbox/outbox/processed folders for integrity and permissions
# Outputs: hub/bridge_selfcheck.json

BASE="${LUKA_HOME:-$HOME/02luka}"
BRIDGE_DIR="${BASE}/bridge"
OUTPUT_FILE="${BASE}/hub/bridge_selfcheck.json"
STUCK_FILE_THRESHOLD_HOURS="${BRIDGE_STUCK_THRESHOLD_HOURS:-24}"

# Ensure output directory exists
mkdir -p "${BASE}/hub"

# Initialize timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Function to get folder status
get_folder_status() {
  local folder_path="$1"
  local status_obj

  if [[ -d "$folder_path" ]]; then
    local perms=$(ls -ld "$folder_path" | awk '{print $1}')
    local file_count=$(find "$folder_path" -maxdepth 1 -type f -o -type d | wc -l)
    ((file_count--)) # Remove the directory itself from count

    # Find oldest file age in hours
    local oldest_file_age=0
    local oldest_file=$(find "$folder_path" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2-)
    if [[ -n "$oldest_file" ]]; then
      local file_timestamp=$(stat -c %Y "$oldest_file" 2>/dev/null || echo 0)
      local current_timestamp=$(date +%s)
      oldest_file_age=$(( (current_timestamp - file_timestamp) / 3600 ))
    fi

    status_obj=$(jq -n \
      --arg exists "true" \
      --arg perms "$perms" \
      --argjson count "$file_count" \
      --argjson age "$oldest_file_age" \
      '{exists: ($exists == "true"), permissions: $perms, file_count: $count, oldest_file_age_hours: $age}')
  else
    status_obj=$(jq -n \
      --arg exists "false" \
      --arg perms "n/a" \
      '{exists: ($exists == "true"), permissions: $perms, file_count: 0, oldest_file_age_hours: 0}')
  fi

  echo "$status_obj"
}

# Function to detect issues for an agent
detect_issues() {
  local agent_id="$1"
  local inbox_path="$2"
  local outbox_path="$3"
  local processed_path="$4"
  local issues="[]"

  # Check if inbox exists
  if [[ ! -d "$inbox_path" ]]; then
    issues=$(echo "$issues" | jq \
      --arg severity "critical" \
      --arg type "missing_folder" \
      --arg msg "Inbox folder missing for agent $agent_id" \
      --arg path "$inbox_path" \
      '. += [{severity: $severity, type: $type, message: $msg, path: $path}]')
  else
    # Check inbox permissions
    local inbox_perms=$(stat -c "%a" "$inbox_path" 2>/dev/null || echo "000")
    if [[ "$inbox_perms" != "755" ]] && [[ "$inbox_perms" != "775" ]] && [[ "$inbox_perms" != "777" ]]; then
      issues=$(echo "$issues" | jq \
        --arg severity "warning" \
        --arg type "permission" \
        --arg msg "Inbox permissions may be restrictive: $inbox_perms" \
        --arg path "$inbox_path" \
        '. += [{severity: $severity, type: $type, message: $msg, path: $path}]')
    fi

    # Check for stuck files (work orders older than threshold)
    # Convert hours to seconds for comparison
    local threshold_seconds=$((STUCK_FILE_THRESHOLD_HOURS * 3600))
    local current_time=$(date +%s)
    local stuck_files=0

    # Find work orders and check their age
    if compgen -G "$inbox_path/WO-*" > /dev/null 2>&1; then
      for wo_dir in "$inbox_path"/WO-*; do
        if [[ -d "$wo_dir" ]]; then
          local wo_mtime=$(stat -c %Y "$wo_dir" 2>/dev/null || echo $current_time)
          local age_seconds=$((current_time - wo_mtime))
          if [[ $age_seconds -gt $threshold_seconds ]]; then
            ((stuck_files++))
          fi
        fi
      done
    fi

    if [[ $stuck_files -gt 0 ]]; then
      issues=$(echo "$issues" | jq \
        --arg severity "warning" \
        --arg type "stuck_file" \
        --arg msg "Found $stuck_files work orders older than ${STUCK_FILE_THRESHOLD_HOURS} hours" \
        --arg path "$inbox_path" \
        '. += [{severity: $severity, type: $type, message: $msg, path: $path}]')
    fi
  fi

  # Check outbox (optional - may not exist for all agents)
  if [[ -d "$outbox_path" ]]; then
    local outbox_perms=$(stat -c "%a" "$outbox_path" 2>/dev/null || echo "000")
    if [[ "$outbox_perms" != "755" ]] && [[ "$outbox_perms" != "775" ]] && [[ "$outbox_perms" != "777" ]]; then
      issues=$(echo "$issues" | jq \
        --arg severity "info" \
        --arg type "permission" \
        --arg msg "Outbox permissions may be restrictive: $outbox_perms" \
        --arg path "$outbox_path" \
        '. += [{severity: $severity, type: $type, message: $msg, path: $path}]')
    fi
  fi

  # Check processed folder
  if [[ ! -d "$processed_path" ]]; then
    issues=$(echo "$issues" | jq \
      --arg severity "warning" \
      --arg type "missing_folder" \
      --arg msg "Processed folder missing (shared across agents)" \
      --arg path "$processed_path" \
      '. += [{severity: $severity, type: $type, message: $msg, path: $path}]')
  fi

  echo "$issues"
}

# Function to calculate agent metrics
calculate_metrics() {
  local inbox_path="$1"
  local processed_path="$2"

  # Count pending work orders
  local pending_wo=0
  if [[ -d "$inbox_path" ]]; then
    pending_wo=$(find "$inbox_path" -maxdepth 1 -type d -name "WO-*" 2>/dev/null | wc -l || echo 0)
  fi

  # Count stuck files (work orders older than threshold)
  local stuck=0
  if [[ -d "$inbox_path" ]]; then
    local threshold_seconds=$((STUCK_FILE_THRESHOLD_HOURS * 3600))
    local current_time=$(date +%s)

    if compgen -G "$inbox_path/WO-*" > /dev/null 2>&1; then
      for wo_dir in "$inbox_path"/WO-*; do
        if [[ -d "$wo_dir" ]]; then
          local wo_mtime=$(stat -c %Y "$wo_dir" 2>/dev/null || echo $current_time)
          local age_seconds=$((current_time - wo_mtime))
          if [[ $age_seconds -gt $threshold_seconds ]]; then
            ((stuck++))
          fi
        fi
      done
    fi
  fi

  # Count processed items
  local processed_count=0
  if [[ -d "$processed_path" ]]; then
    processed_count=$(find "$processed_path" -maxdepth 1 -type f 2>/dev/null | wc -l || echo 0)
  fi

  jq -n \
    --argjson pending "$pending_wo" \
    --argjson stuck "$stuck" \
    --argjson processed "$processed_count" \
    '{pending_work_orders: $pending, stuck_files: $stuck, processed_count: $processed}'
}

# Function to determine agent status based on issues
determine_status() {
  local issues="$1"
  local critical_count=$(echo "$issues" | jq '[.[] | select(.severity == "critical")] | length')
  local warning_count=$(echo "$issues" | jq '[.[] | select(.severity == "warning")] | length')

  if [[ $critical_count -gt 0 ]]; then
    echo "critical"
  elif [[ $warning_count -gt 0 ]]; then
    echo "warning"
  else
    echo "healthy"
  fi
}

# Main scanning logic
echo "🔍 Starting bridge self-check..."

# Discover all agents from bridge/inbox
agents_array="[]"
processed_path="${BRIDGE_DIR}/processed"

if [[ -d "${BRIDGE_DIR}/inbox" ]]; then
  for agent_dir in "${BRIDGE_DIR}/inbox"/*; do
    if [[ -d "$agent_dir" ]]; then
      agent_id=$(basename "$agent_dir")

      echo "  Checking agent: $agent_id"

      inbox_path="$agent_dir"
      outbox_path="${BRIDGE_DIR}/outbox/${agent_id}"

      # Get folder statuses
      inbox_status=$(get_folder_status "$inbox_path")
      outbox_status=$(get_folder_status "$outbox_path")
      processed_status=$(get_folder_status "$processed_path")

      # Detect issues
      issues=$(detect_issues "$agent_id" "$inbox_path" "$outbox_path" "$processed_path")

      # Calculate metrics
      metrics=$(calculate_metrics "$inbox_path" "$processed_path")

      # Determine agent status
      agent_status=$(determine_status "$issues")

      # Build agent object
      agent_obj=$(jq -n \
        --arg agent_id "$agent_id" \
        --arg status "$agent_status" \
        --argjson inbox "$inbox_status" \
        --argjson outbox "$outbox_status" \
        --argjson processed "$processed_status" \
        --argjson issues "$issues" \
        --argjson metrics "$metrics" \
        '{
          agent_id: $agent_id,
          status: $status,
          folders: {
            inbox: $inbox,
            outbox: $outbox,
            processed: $processed
          },
          issues: $issues,
          metrics: $metrics
        }')

      agents_array=$(echo "$agents_array" | jq --argjson agent "$agent_obj" '. += [$agent]')
    fi
  done
else
  echo "  ⚠️  Bridge inbox directory not found: ${BRIDGE_DIR}/inbox"
fi

# Calculate summary
total_agents=$(echo "$agents_array" | jq 'length')
healthy_count=$(echo "$agents_array" | jq '[.[] | select(.status == "healthy")] | length')
warning_count=$(echo "$agents_array" | jq '[.[] | select(.status == "warning")] | length')
critical_count=$(echo "$agents_array" | jq '[.[] | select(.status == "critical")] | length')
total_issues=$(echo "$agents_array" | jq '[.[].issues[]] | length')

# Determine overall status
overall_status="healthy"
if [[ $critical_count -gt 0 ]]; then
  overall_status="critical"
elif [[ $warning_count -gt 0 ]]; then
  overall_status="warning"
fi

# Build final report
report=$(jq -n \
  --arg timestamp "$TIMESTAMP" \
  --arg status "$overall_status" \
  --argjson agents "$agents_array" \
  --argjson total "$total_agents" \
  --argjson healthy "$healthy_count" \
  --argjson warning "$warning_count" \
  --argjson critical "$critical_count" \
  --argjson issues "$total_issues" \
  '{
    timestamp: $timestamp,
    status: $status,
    agents: $agents,
    summary: {
      total_agents: $total,
      healthy_count: $healthy,
      warning_count: $warning,
      critical_count: $critical,
      total_issues: $issues
    }
  }')

# Write output
echo "$report" | jq '.' > "$OUTPUT_FILE"

echo "✅ Bridge self-check complete"
echo "📄 Report written to: $OUTPUT_FILE"
echo "📊 Status: $overall_status ($total_agents agents, $total_issues issues)"

# Exit with appropriate code
if [[ "$overall_status" == "critical" ]]; then
  exit 1
elif [[ "$overall_status" == "warning" ]]; then
  exit 0  # Warnings don't fail the check
else
  exit 0
fi
