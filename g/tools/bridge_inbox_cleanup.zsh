#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Bridge Inbox Cleanup Tool
# ═══════════════════════════════════════════════════════════════════════
# Cleans up stale Work Orders from bridge inbox directories
# Archives old WOs and removes empty directories
# Usage: g/tools/bridge_inbox_cleanup.zsh [--days N] [--dry-run]
# ═══════════════════════════════════════════════════════════════════════

set -uo pipefail

# ═══════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════
DAYS_THRESHOLD=7
DRY_RUN=false
ROOT="${HOME}/02luka"
INBOX_DIRS=(
  "${ROOT}/bridge/inbox/CLC"
  "${ROOT}/bridge/inbox/ENTRY"
  "${ROOT}/bridge/inbox/LIAM"
)
ARCHIVE_DIR="${ROOT}/bridge/archive"
PROCESSED_DIR="${ROOT}/bridge/processed"
LOG_FILE="${ROOT}/g/telemetry/bridge_inbox_cleanup.jsonl"

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
      echo "Usage: $0 [--days N] [--dry-run]"
      exit 1
      ;;
  esac
done

# Create directories
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$PROCESSED_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# ═══════════════════════════════════════════
# Logging
# ═══════════════════════════════════════════
log() {
  local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"ts\":\"$ts\",\"event\":\"$1\",\"wo_id\":\"${2:-}\",\"inbox\":\"${3:-}\",\"action\":\"${4:-}\"}" >> "$LOG_FILE"
}

# ═══════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════
get_file_age_days() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local file_time=$(stat -f "%m" "$file" 2>/dev/null || echo "0")
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

check_wo_processed() {
  local wo_id="$1"
  local inbox_name="$2"
  
  # Check if ACK exists in outbox
  if [[ -f "${ROOT}/bridge/outbox/${inbox_name}/${wo_id}.ack.json" ]]; then
    echo "processed"
    return 0
  fi
  
  # Check if in processed directory
  if [[ -f "${PROCESSED_DIR}/${inbox_name}/${wo_id}.yaml" ]] || \
     [[ -f "${PROCESSED_DIR}/${inbox_name}/${wo_id}.json" ]]; then
    echo "processed"
    return 0
  fi
  
  echo "pending"
}

archive_wo() {
  local wo_file="$1"
  local wo_id="$2"
  local inbox_name="$3"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY-RUN] Would archive $wo_id from $inbox_name"
    return 0
  fi
  
  local archive_subdir="${ARCHIVE_DIR}/${inbox_name}/$(date +%Y%m)"
  mkdir -p "$archive_subdir"
  
  if [[ -f "$wo_file" ]]; then
    mv "$wo_file" "${archive_subdir}/" 2>/dev/null && {
      log "wo_archived" "$wo_id" "$inbox_name" "archived"
      echo "  ✅ Archived: $wo_id"
    } || {
      echo "  ❌ Failed to archive: $wo_id"
      log "wo_archive_failed" "$wo_id" "$inbox_name" "archive_failed"
    }
  fi
}

# ═══════════════════════════════════════════
# Main Cleanup Logic
# ═══════════════════════════════════════════
main() {
  echo "╔═══════════════════════════════════════════════════════════════════╗"
  echo "║          🧹 Bridge Inbox Cleanup Tool                              ║"
  echo "╚═══════════════════════════════════════════════════════════════════╝"
  echo "📅 Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "⏱️  Age Threshold: $DAYS_THRESHOLD days"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 Mode: DRY-RUN (no changes will be made)"
  else
    echo "⚡ Mode: LIVE (will archive files)"
  fi
  echo ""
  
  local total_processed=0
  local total_archived=0
  local total_skipped=0
  
  for inbox_dir in "${INBOX_DIRS[@]}"; do
    local inbox_name=$(basename "$inbox_dir")
    
    if [[ ! -d "$inbox_dir" ]]; then
      echo "⏭️  Skipping $inbox_name (directory not found)"
      continue
    fi
    
    echo "📁 Processing: $inbox_name"
    
    # Process YAML files
    for wo_file in "$inbox_dir"/*.yaml "$inbox_dir"/*.json; do
      [[ ! -f "$wo_file" ]] && continue
      
      local wo_id=$(basename "$wo_file" .yaml)
      wo_id=$(basename "$wo_id" .json)
      
      # Skip templates and special files
      if [[ "$wo_id" == ".DS_Store" ]] || [[ "$wo_id" == "templates" ]]; then
        continue
      fi
      
      local age_days=$(get_file_age_days "$wo_file")
      
      if [[ $age_days -lt $DAYS_THRESHOLD ]]; then
        ((total_skipped++))
        continue
      fi
      
      ((total_processed++))
      echo "  📋 $wo_id (${age_days} days old)"
      
      # Check if already processed
      local status=$(check_wo_processed "$wo_id" "$inbox_name")
      
      if [[ "$status" == "processed" ]]; then
        echo "    ℹ️  Already processed (ACK exists), archiving..."
        archive_wo "$wo_file" "$wo_id" "$inbox_name"
        ((total_archived++))
      else
        echo "    ⚠️  Still pending (no ACK found), skipping..."
        log "wo_skipped_pending" "$wo_id" "$inbox_name" "pending_no_ack"
      fi
    done
    
    # Clean up empty directories
    if [[ "$DRY_RUN" != "true" ]]; then
      find "$inbox_dir" -type d -empty -delete 2>/dev/null || true
    fi
    
    echo ""
  done
  
  # Summary
  echo "╔═══════════════════════════════════════════════════════════════════╗"
  echo "║                    📊 Cleanup Summary                             ║"
  echo "╚═══════════════════════════════════════════════════════════════════╝"
  echo "Total files checked: $total_processed"
  echo "Files archived: $total_archived"
  echo "Files skipped (pending): $total_skipped"
  echo ""
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 This was a dry run. Use without --dry-run to perform actual cleanup."
  else
    echo "✅ Cleanup complete. Log: $LOG_FILE"
  fi
  
  log "cleanup_complete" "" "" "processed=$total_processed,archived=$total_archived,skipped=$total_skipped"
}

# Run main function
main

