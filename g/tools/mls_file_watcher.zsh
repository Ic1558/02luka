#!/usr/bin/env zsh
# MLS File Watcher - Phase 3: File Watcher Layer
# Monitors file changes and logs to MLS with rate limiting

set -e

# Configuration
PROJECT_ROOT="${LAC_BASE_DIR:-$HOME/LocalProjects/02luka_local_g}"
MLS_ADD="${PROJECT_ROOT}/tools/mls_add.zsh"
ERROR_LOG="${PROJECT_ROOT}/g/logs/mls_watcher_errors.log"
DROP_LOG="${PROJECT_ROOT}/g/logs/mls_watcher_drops.log"
STATE_DIR="${PROJECT_ROOT}/g/data/mls_watcher"
RATE_STATE="${STATE_DIR}/rate_limit.state"

# Rate limiting: max 10 events per minute
MAX_EVENTS_PER_MINUTE=10
WINDOW_SECONDS=60

# Debouncing: 3-second window
DEBOUNCE_SECONDS=3

# Directories to watch
WATCH_DIRS=(
    "${PROJECT_ROOT}/agents"
    "${PROJECT_ROOT}/g/specs"
    "${PROJECT_ROOT}/tools"
)

# Initialize
mkdir -p "$(dirname "$ERROR_LOG")"
mkdir -p "$STATE_DIR"

log_error() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$ERROR_LOG"
}

log_drop() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$DROP_LOG"
}

# Check rate limit
check_rate_limit() {
    local now=$(date +%s)
    local count=0
    
    # Read state file (contains timestamps)
    if [[ -f "$RATE_STATE" ]]; then
        while IFS= read -r ts; do
            # Count events in the last 60 seconds
            if (( now - ts < WINDOW_SECONDS )); then
                ((count++))
            fi
        done < "$RATE_STATE"
    fi
    
    if (( count >= MAX_EVENTS_PER_MINUTE )); then
        return 1  # Rate limit exceeded
    fi
    
    # Add current timestamp
    echo "$now" >> "$RATE_STATE"
    
    # Clean old timestamps (keep only last 100)
    tail -100 "$RATE_STATE" > "${RATE_STATE}.tmp" && mv "${RATE_STATE}.tmp" "$RATE_STATE"
    
    return 0
}

# Process file change event
process_event() {
    local file_path="$1"
    local event_type="$2"  # created, modified, deleted
    
    # Filter out unwanted files
    case "$file_path" in
        *.pyc|*__pycache__*|*.log|*.tmp|*.swp|*/.git/*) 
            return 0
            ;;
    esac
    
    # Check rate limit
    if ! check_rate_limit; then
        log_drop "Rate limit exceeded, dropped: $file_path"
        return 0
    fi
    
    # Get relative path
    local rel_path="${file_path#$PROJECT_ROOT/}"
    
    # Log to MLS (async)
    {
        "$MLS_ADD" \
            --type improvement \
            --title "File ${event_type}: $(basename "$file_path")" \
            --summary "Path: ${rel_path}" \
            --producer fswatch \
            --context local \
            --tags "dev,file-save,local,${event_type}" \
            --author system \
            --confidence 0.7 \
            2>> "$ERROR_LOG"
    } &
}

# Main watcher function
watch_files() {
    echo "[MLS Watcher] Starting file watcher..."
    echo "[MLS Watcher] Watching: ${WATCH_DIRS[@]}"
    
    # Use fswatch with:
    # -r: recursive
    # -l: latency (debounce)
    # --event Created,Updated,Removed: specific events
    # -0: null-separated output
    
    fswatch -r -l "$DEBOUNCE_SECONDS" \
        --event Created --event Updated --event Removed \
        -0 \
        "${WATCH_DIRS[@]}" | \
    while IFS= read -r -d '' event; do
        # Parse event (format: <flags> <path>)
        # For simplicity, treat all as "modified"
        # (fswatch flags are complex, basic detection for now)
        
        if [[ "$event" =~ "Created" ]]; then
            process_event "$event" "created"
        elif [[ "$event" =~ "Removed" ]]; then
            process_event "$event" "deleted"
        else
            process_event "$event" "modified"
        fi
    done
}

# Check dependencies
if ! command -v fswatch &> /dev/null; then
    log_error "fswatch not found. Install with: brew install fswatch"
    echo "Error: fswatch not installed. See $ERROR_LOG"
    exit 1
fi

if [[ ! -x "$MLS_ADD" ]]; then
    log_error "mls_add.zsh not found or not executable: $MLS_ADD"
    echo "Error: mls_add.zsh not found. See $ERROR_LOG"
    exit 1
fi

# Run watcher
watch_files
