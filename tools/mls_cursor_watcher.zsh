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
# Returns path to temp file containing JSON (using -c for inline Python)
extract_prompts() {
  local db_file="$1"
  local output_file="$2"  # Temp file to write JSON to
  local retries=3
  local backoff=1
  
  for i in $(seq 1 $retries); do
    # Pipe sqlite3 output directly to Python -c (robust, no heredoc conflict)
    sqlite3 "$db_file" "PRAGMA read_uncommitted=1; SELECT value FROM ItemTable WHERE key = 'aiService.prompts';" 2>&1 | \
    python3 -c "import json,sys; raw=sys.stdin.read(); sys.exit('No JSON on stdin') if not raw.strip() else None; data=json.loads(raw); print(json.dumps(data,ensure_ascii=False))" > "$output_file" 2>&1
    
    local exit_code=$?
    
    # Check if file has content and is valid JSON
    if [[ $exit_code -eq 0 ]] && [[ -s "$output_file" ]]; then
      # Quick validation - check if it starts with '[' or '{' (JSON)
      local first_char=$(head -c 1 "$output_file")
      if [[ "$first_char" == "[" ]] || [[ "$first_char" == "{" ]]; then
        return 0
      fi
    fi
    
    # Check for SQLITE_BUSY or database locked errors
    if grep -q "SQLITE_BUSY\|database is locked" "$output_file" 2>/dev/null; then
      if [[ $i -lt $retries ]]; then
        log "Database locked, retrying in ${backoff}s (attempt $i/$retries)"
        sleep $backoff
        backoff=$((backoff * 2))
      else
        log_error "Database locked after $retries attempts"
        return 1
      fi
    else
      # Log error on final attempt
      if [[ $i -eq $retries ]]; then
        local error_msg=$(head -c 200 "$output_file" 2>/dev/null || echo "unknown error")
        log_error "Failed to extract prompts (exit=$exit_code): $error_msg"
      fi
    fi
  done
  
  return 1
}

# Get composer metadata (using -c for inline Python)
get_composer_metadata() {
  local db_file="$1"
  
  sqlite3 "$db_file" "PRAGMA read_uncommitted=1; SELECT value FROM ItemTable WHERE key = 'composer.composerData';" 2>/dev/null | \
  python3 -c "import json,sys; raw=sys.stdin.read(); print('{}') if not raw.strip() else print(json.dumps(json.loads(raw),ensure_ascii=False))" 2>/dev/null || echo "{}"
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
  
  # Extract prompts to temp file (avoids shell variable issues with control characters)
  local temp_json=$(mktemp)
  extract_prompts "$db_file" "$temp_json"
  local extract_exit=$?
  
  if [[ $extract_exit -ne 0 ]] || [[ ! -s "$temp_json" ]]; then
    log_error "Failed to extract prompts (exit=$extract_exit)"
    rm -f "$temp_json"
    return 1
  fi
  
  local json_size=$(stat -f%z "$temp_json" 2>/dev/null || echo "0")
  log "Extracted prompts JSON (size: $json_size bytes)"
  
  # Parse prompts - read directly from file
  local current_count=$(python3 <<PYTHON 2>>"$LOG_FILE" || echo "0"
import json
import sys

try:
    with open("$temp_json", "r", encoding="utf-8") as f:
        data = json.load(f)
    print(len(data) if isinstance(data, list) else 0)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
)
  
  if [[ $current_count -eq 0 ]]; then
    log_error "Failed to parse prompts JSON or empty array"
    rm -f "$temp_json"
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
  
  if [[ $new_prompts -le 0 ]]; then
    log "No new prompts to process"
    rm -f "$temp_json"
    return 0
  fi
  
  # Extract new prompts (last N prompts) - read directly from temp file
  local temp_prompts=$(mktemp)
  
  python3 <<PYTHON > "$temp_prompts" 2>>"$LOG_FILE"
import json
import hashlib
import sys

try:
    with open("$temp_json", "r", encoding="utf-8") as f:
        prompts = json.load(f)
    
    state_count = int("${last_count}")
    
    # Get new prompts (from last_count to end)
    new_prompts = prompts[state_count:]
    
    for i, prompt in enumerate(new_prompts):
        text = prompt.get('text', '')
        cmd_type = prompt.get('commandType', '')
        
        # Generate hash
        prompt_hash = hashlib.sha256(text.encode()).hexdigest()
        
        # Output: text|commandType|hash (escape newlines and pipes for shell)
        text_escaped = text.replace('\n', r'\n').replace('\r', r'\r').replace('|', r'\|')
        print(f"{text_escaped}|{cmd_type}|{prompt_hash}")
        
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
  
  local py_exit=$?
  if [[ $py_exit -ne 0 ]]; then
    log_error "Failed to process prompts JSON"
    rm -f "$temp_json" "$temp_prompts"
    return 1
  fi
  
  rm -f "$temp_json"
  
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
