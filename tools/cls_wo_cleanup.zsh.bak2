#!/usr/bin/env zsh
# CLS Work Order Cleanup & Recheck Bot
# Finds stale WOs and updates their status based on evidence
# Usage: tools/cls_wo_cleanup.zsh [--days N] [--dry-run]

set -uo pipefail

DAYS_THRESHOLD=7
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --days)
      DAYS_THRESHOLD="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done
WO_STATUS_FILE="$HOME/02luka/memory/cls/wo_status.jsonl"
WO_INBOX="$HOME/02luka/bridge/inbox/CLC"
ARCHIVE_DIR="$HOME/02luka/bridge/archive"
LOG_FILE="$HOME/02luka/g/telemetry/cls_wo_cleanup.jsonl"
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$ARCHIVE_DIR"

log() {
  local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"ts\":\"$ts\",\"event\":\"$1\",\"wo_id\":\"${2:-}\",\"status\":\"${3:-}\",\"reason\":\"${4:-}\"}" >> "$LOG_FILE"
}

check_redis_result() {
  local wo_id="$1"
  if command -v redis-cli >/dev/null 2>&1; then
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" GET "wo:result:$wo_id" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || echo ""
  else
    echo ""
  fi
}

check_evidence() {
  local wo_dir="$1"
  if [[ -d "$wo_dir/evidence" ]]; then
    if [[ -f "$wo_dir/evidence/completed.json" ]] || [[ -f "$wo_dir/evidence/success.json" ]]; then
      echo "completed"
    elif [[ -f "$wo_dir/evidence/failed.json" ]] || [[ -f "$wo_dir/evidence/error.json" ]]; then
      echo "failed"
    else
      echo ""
    fi
  else
    echo ""
  fi
}

check_mls_reference() {
  local wo_id="$1"
  if [[ -f "$HOME/02luka/mls/ledger/$(date +%Y-%m-%d).jsonl" ]]; then
    grep -q "\"wo_id\":\"$wo_id\"" "$HOME/02luka/mls/ledger/"*.jsonl 2>/dev/null && echo "completed" || echo ""
  else
    echo ""
  fi
}

get_wo_age_days() {
  local wo_file="$1"
  if [[ -f "$wo_file" ]]; then
    # Try to get created_at from YAML/JSON first
    local created_line=$(grep -E "created_at|createdAt" "$wo_file" 2>/dev/null | head -1 || echo "")
    if [[ -n "$created_line" ]]; then
      # Extract date from YAML format: created_at: "2025-10-30T05:29:04+07:00"
      local created_at=$(echo "$created_line" | sed -E 's/.*created_at[^:]*: *["'\'']?([^"'\'']+)["'\'']?.*/\1/' | sed -E 's/^[[:space:]]+//' | sed -E 's/[[:space:]]+$//')
      
      # Parse ISO date (2025-10-30T05:29:04+07:00 or 2025-10-30T05:29:04Z)
      local date_part=$(echo "$created_at" | cut -d'T' -f1)
      if [[ -n "$date_part" ]] && [[ "$date_part" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        local now=$(date +%s)
        local file_time=$(date -j -f "%Y-%m-%d" "$date_part" +%s 2>/dev/null || echo "0")
        if [[ $file_time -gt 0 ]]; then
          echo $(( (now - file_time) / 86400 ))
          return
        fi
      fi
    fi
    
    # Fallback to file modification time
    local file_time=$(stat -f "%m" "$wo_file" 2>/dev/null || echo "0")
    local now=$(date +%s)
    if [[ $file_time -gt 0 ]]; then
      echo $(( (now - file_time) / 86400 ))
    else
      echo "999"
    fi
  else
    echo "999"
  fi
}

update_wo_status() {
  local wo_id="$1"
  local new_status="$2"
  local reason="$3"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY-RUN] Would update $wo_id: $new_status ($reason)"
    return 0
  fi
  
  local temp_file=$(mktemp)
  local found=false
  local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  # Process JSONL file line by line
  if [[ -f "$WO_STATUS_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ -n "$line" ]]; then
        local line_wo_id=$(echo "$line" | jq -r '.wo_id // empty' 2>/dev/null || echo "")
        if [[ "$line_wo_id" == "$wo_id" ]]; then
          # Update existing entry
          echo "$line" | jq --arg status "$new_status" --arg ts "$ts" --arg reason "$reason" \
             '.status = $status | .updated = $ts | .reason = $reason' 2>/dev/null >> "$temp_file" || echo "$line" >> "$temp_file"
          found=true
        else
          # Keep other entries as-is
          echo "$line" >> "$temp_file"
        fi
      fi
    done < "$WO_STATUS_FILE"
  fi
  
  # Add new entry if not found
  if [[ "$found" == "false" ]]; then
    echo "{\"wo_id\":\"$wo_id\",\"status\":\"$new_status\",\"updated\":\"$ts\",\"reason\":\"$reason\"}" >> "$temp_file"
  fi
  
  mv "$temp_file" "$WO_STATUS_FILE"
  log "wo_status_updated" "$wo_id" "$new_status" "$reason"
}

archive_wo() {
  local wo_id="$1"
  local wo_path="$WO_INBOX/$wo_id"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY-RUN] Would archive $wo_id to $ARCHIVE_DIR/"
    return 0
  fi
  
  if [[ -d "$wo_path" ]]; then
    mv "$wo_path" "$ARCHIVE_DIR/" 2>/dev/null && log "wo_archived" "$wo_id" "archived" "Old completed WO"
  fi
}

main() {
  echo "🔍 CLS Work Order Cleanup Bot"
  echo "   Threshold: $DAYS_THRESHOLD days"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "   Mode: DRY-RUN"
  else
    echo "   Mode: LIVE"
  fi
  echo ""
  
  local processed=0
  local updated=0
  local archived=0
  
  # Process each WO directory
  for wo_dir in "$WO_INBOX"/WO-*; do
    [[ ! -d "$wo_dir" ]] && continue
    
    local wo_id=$(basename "$wo_dir")
    local wo_file="$wo_dir/${wo_id}.yaml"
    [[ ! -f "$wo_file" ]] && wo_file="$wo_dir/${wo_id}.json"
    [[ ! -f "$wo_file" ]] && continue
    
    local age_days=$(get_wo_age_days "$wo_file")
    echo "  [DEBUG] $wo_id: age=$age_days days, threshold=$DAYS_THRESHOLD" >&2
    [[ $age_days -lt $DAYS_THRESHOLD ]] && continue
    
    ((processed++))
    echo "📋 $wo_id (${age_days} days old)"
    
    # Check multiple sources for completion status
    local redis_status=$(check_redis_result "$wo_id")
    local evidence_status=$(check_evidence "$wo_dir")
    local mls_status=$(check_mls_reference "$wo_id")
    
    # Determine actual status
    local actual_status=""
    local reason=""
    
    if [[ -n "$redis_status" ]]; then
      actual_status="$redis_status"
      reason="Redis result found"
    elif [[ -n "$evidence_status" ]]; then
      actual_status="$evidence_status"
      reason="Evidence directory check"
    elif [[ -n "$mls_status" ]]; then
      actual_status="$mls_status"
      reason="MLS ledger reference"
    elif [[ $age_days -gt 30 ]]; then
      actual_status="abandoned"
      reason="Older than 30 days with no activity"
    elif [[ $age_days -ge 14 ]]; then
      # Test WOs 14+ days old with no evidence are likely abandoned
      actual_status="abandoned"
      reason="Test WO 14+ days old with no completion evidence"
    else
      echo "  ⚠️  No completion evidence found, keeping current status"
      continue
    fi
    
    # Update status
    echo "  ✅ Status: $actual_status ($reason)"
    update_wo_status "$wo_id" "$actual_status" "$reason"
    ((updated++))
    
    # Archive if completed and old
    if [[ "$actual_status" == "completed" ]] && [[ $age_days -gt 30 ]]; then
      archive_wo "$wo_id"
      ((archived++))
    fi
    
    echo ""
  done
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 Summary:"
  echo "   Processed: $processed WOs"
  echo "   Updated: $updated statuses"
  echo "   Archived: $archived WOs"
  echo ""
  
  log "cleanup_complete" "" "success" "Processed $processed, updated $updated, archived $archived"
}

main "$@"
