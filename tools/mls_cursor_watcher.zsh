#!/usr/bin/env zsh
# MLS Cursor Watcher - Auto-capture prompts/conversations
# Monitors Cursor SQLite database and records new prompts to MLS Ledger
# Usage: mls_cursor_watcher.zsh [--dry-run]
set -uo pipefail

BASE="$HOME/02luka"
CURSOR_STORAGE="$HOME/Library/Application Support/Cursor/User/workspaceStorage"
STATE_FILE="$BASE/memory/cls/mls_cursor_watcher_state.json"
LOG_FILE="$BASE/logs/mls_cursor_watcher.log"
TARGET_WORKSPACE="$HOME/02luka"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

mkdir -p "$(dirname "$STATE_FILE")" "$(dirname "$LOG_FILE")"

# Logging function
log() {
  local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] $*" >> "$LOG_FILE"
}

# Error logging
log_error() {
  log "ERROR: $*"
  [[ "$DRY_RUN" != "true" ]] && echo "⚠️  $*" >&2 || echo "[DRY-RUN] $*" >&2
}

# Find target database (most recent state.vscdb)
find_target_db() {
  local db_file=$(find "$CURSOR_STORAGE" -name "state.vscdb" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || echo "")
  
  if [[ -z "$db_file" ]] || [[ ! -f "$db_file" ]]; then
    log_error "No state.vscdb found"
    return 1
  fi
  
  echo "$db_file"
}

# Load state file
load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    local last_count=$(jq -r '.last_prompt_count // 0' "$STATE_FILE" 2>/dev/null || echo "0")
    local last_timestamp=$(jq -r '.last_timestamp // ""' "$STATE_FILE" 2>/dev/null || echo "")
    echo "$last_count|$last_timestamp"
  else
    echo "0|"
  fi
}

# Save state file (atomic write)
save_state() {
  local count="$1"
  local timestamp="$2"
  local temp_file="${STATE_FILE}.tmp"
  
  echo "{\"last_prompt_count\":$count,\"last_timestamp\":\"$timestamp\",\"updated\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$temp_file"
  
  # Validate JSON
  if jq . "$temp_file" >/dev/null 2>&1; then
    mv "$temp_file" "$STATE_FILE"
  else
    log_error "Invalid JSON in state file"
    rm -f "$temp_file"
    return 1
  fi
}

# Extract prompts from database with retry logic
extract_prompts() {
  local db_file="$1"
  local retries=3
  local backoff=1
  
  for i in $(seq 1 $retries); do
    # Use PRAGMA read_uncommitted for read-only queries
    # Note: PRAGMA must be on separate line or use separate connection
    local result=$(sqlite3 "$db_file" <<SQL 2>&1
PRAGMA read_uncommitted=1;
SELECT value FROM ItemTable WHERE key = 'aiService.prompts';
SQL
)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]] && [[ -n "$result" ]]; then
      echo "$result"
      return 0
    fi
    
    # Check for SQLITE_BUSY error
    if echo "$result" | grep -q "SQLITE_BUSY\|database is locked"; then
      if [[ $i -lt $retries ]]; then
        log "Database locked, retrying in ${backoff}s (attempt $i/$retries)"
        sleep $backoff
        backoff=$((backoff * 2))
      else
        log_error "Database locked after $retries attempts"
        return 1
      fi
    else
      # Don't log error on first attempt (might be normal)
      if [[ $i -eq $retries ]]; then
        log_error "Failed to extract prompts (exit=$exit_code): ${result:0:200}"
      fi
      # Continue to retry
    fi
  done
  
  return 1
}

# Get composer metadata
get_composer_metadata() {
  local db_file="$1"
  sqlite3 "$db_file" "PRAGMA read_uncommitted=1; SELECT value FROM ItemTable WHERE key = 'composer.composerData';" 2>/dev/null || echo "{}"
}

# Generate hash for deduplication
generate_prompt_hash() {
  local text="$1"
  echo -n "$text" | shasum -a 256 | cut -d' ' -f1
}

# Check if prompt already recorded in MLS Ledger
is_prompt_recorded() {
  local prompt_hash="$1"
  local ledger_dir="$BASE/mls/ledger"
  
  # Check last 7 days of ledger files
  for i in {0..7}; do
    local date_str=$(date -u -v-${i}d +%Y-%m-%d 2>/dev/null || date -u -d "$i days ago" +%Y-%m-%d 2>/dev/null || echo "")
    if [[ -n "$date_str" ]] && [[ -f "$ledger_dir/${date_str}.jsonl" ]]; then
      if grep -q "\"prompt_hash\":\"$prompt_hash\"" "$ledger_dir/${date_str}.jsonl" 2>/dev/null; then
        return 0  # Found
      fi
    fi
  done
  
  return 1  # Not found
}

# Record prompt to MLS Ledger
record_prompt() {
  local prompt_text="$1"
  local command_type="${2:-}"
  local composer_name="${3:-}"
  local prompt_hash="$4"
  
  # Truncate prompt for summary (first 200 chars)
  local summary="${prompt_text:0:200}"
  [[ ${#prompt_text} -gt 200 ]] && summary="${summary}..."
  
  local title="Cursor Prompt"
  [[ -n "$composer_name" ]] && title="Cursor Prompt: $composer_name"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would record: $title - ${summary:0:50}..."
    echo "[DRY-RUN] Would record prompt to MLS Ledger"
    return 0
  fi
  
  # Record via mls_auto_record.zsh
  if [[ -f "$BASE/tools/mls_auto_record.zsh" ]]; then
    "$BASE/tools/mls_auto_record.zsh" \
      "learning" \
      "$title" \
      "Prompt: $summary" \
      "cursor,prompt,training,auto-captured" \
      "" 2>>"$LOG_FILE" || {
      log_error "Failed to record prompt to MLS Ledger"
      return 1
    }
    
    log "Recorded prompt: ${summary:0:50}..."
    return 0
  else
    log_error "mls_auto_record.zsh not found"
    return 1
  fi
}

# Main processing function
process_new_prompts() {
  local db_file=$(find_target_db)
  [[ -z "$db_file" ]] && return 1
  
  log "Processing prompts from: $db_file"
  
  # Extract prompts with retry logic
  local prompts_json=$(extract_prompts "$db_file")
  if [[ -z "$prompts_json" ]]; then
    log_error "Failed to extract prompts"
    return 1
  fi
  
  # Parse prompts - handle potential JSON parsing errors
  local current_count=$(echo "$prompts_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data) if isinstance(data, list) else 0)" 2>/dev/null || echo "0")
  
  if [[ $current_count -eq 0 ]]; then
    log_error "Failed to parse prompts JSON or empty array"
    return 1
  fi
  
  # Load previous state
  local state=$(load_state)
  local last_count=$(echo "$state" | cut -d'|' -f1)
  local last_timestamp=$(echo "$state" | cut -d'|' -f2)
  
  log "Current prompts: $current_count, Last processed: $last_count"
  
  # If no new prompts, exit
  if [[ $current_count -le $last_count ]]; then
    log "No new prompts (current=$current_count, last=$last_count)"
    return 0
  fi
  
  # Get composer metadata for context
  local composer_data=$(get_composer_metadata "$db_file")
  
  # Process new prompts
  local new_prompts=$((current_count - last_count))
  log "Found $new_prompts new prompt(s)"
  
  # Extract new prompts (last N prompts) - use temp file for Python output
  local temp_prompts=$(mktemp)
  echo "$prompts_json" | python3 <<PYTHON > "$temp_prompts"
import sys
import json
import hashlib

try:
    prompts = json.load(sys.stdin)
    state_count = int("${last_count}")
    
    # Get new prompts (from last_count to end)
    new_prompts = prompts[state_count:]
    
    for i, prompt in enumerate(new_prompts):
        text = prompt.get('text', '')
        cmd_type = prompt.get('commandType', '')
        
        # Generate hash
        prompt_hash = hashlib.sha256(text.encode()).hexdigest()
        
        # Output: text|commandType|hash
        print(f"{text}|{cmd_type}|{prompt_hash}")
        
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
  
  local processed=0
  while IFS='|' read -r prompt_text command_type prompt_hash; do
    # Skip if already recorded
    if is_prompt_recorded "$prompt_hash"; then
      log "Skipping already recorded prompt (hash: ${prompt_hash:0:8}...)"
      continue
    fi
    
    # Try to match to composer (simplified - use most recent composer)
    local composer_name=$(echo "$composer_data" | python3 -c "import sys, json; data=json.load(sys.stdin); composers=data.get('allComposers',[]); print(composers[0].get('name','') if composers else '')" 2>/dev/null || echo "")
    
    # Record prompt
    if record_prompt "$prompt_text" "$command_type" "$composer_name" "$prompt_hash"; then
      processed=$((processed + 1))
    fi
  done < "$temp_prompts"
  
  rm -f "$temp_prompts"
  
  # Update state
  local new_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if save_state "$current_count" "$new_timestamp"; then
    log "Updated state: count=$current_count, timestamp=$new_timestamp, processed=$processed"
  else
    log_error "Failed to save state"
  fi
  
  return 0
}

# Main execution
main() {
  log "=== MLS Cursor Watcher Started ==="
  [[ "$DRY_RUN" == "true" ]] && log "Mode: DRY-RUN"
  
  # Check dependencies
  if ! command -v sqlite3 >/dev/null 2>&1; then
    log_error "sqlite3 not available"
    exit 1
  fi
  
  if ! command -v jq >/dev/null 2>&1; then
    log_error "jq not available"
    exit 1
  fi
  
  if ! command -v python3 >/dev/null 2>&1; then
    log_error "python3 not available"
    exit 1
  fi
  
  # Process prompts
  process_new_prompts || {
    log_error "Failed to process prompts"
    exit 1
  }
  
  log "=== MLS Cursor Watcher Completed ==="
}

# Run main
main "$@"

