#!/usr/bin/env zsh
# Process Watchdog - Track processes >500MB, detect memory leaks
# Runs every 5 minutes, publishes alerts to Redis

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Config
THRESHOLD_MB=500
LEAK_THRESHOLD_MB=100
LEAK_WINDOW_MINUTES=5
TRACK_FILE="/tmp/process_watchdog_track.json"
REDIS_CHANNEL="02luka:alerts:ram"
LOG_FILE="$HOME/02luka/logs/process_watchdog.log"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Helper: Log with timestamp
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Helper: Publish alert to Redis
publish_alert() {
    local alert_type="$1"
    local message="$2"
    local pid="$3"
    local cmd="$4"
    local rss_mb="$5"
    local growth_mb="$6"
    
    local alert_json
    alert_json=$(jq -n \
        --arg type "$alert_type" \
        --arg message "$message" \
        --argjson pid "$pid" \
        --arg cmd "$cmd" \
        --argjson rss_mb "$rss_mb" \
        --argjson growth_mb "$growth_mb" \
        --arg timestamp "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        '{
            type: $type,
            severity: "warning",
            message: $message,
            pid: $pid,
            command: $cmd,
            rss_mb: $rss_mb,
            growth_mb: $growth_mb,
            timestamp: $timestamp
        }')
    
    # Try to publish to Redis
    if command -v redis-cli >/dev/null 2>&1; then
        local redis_result=1
        if [[ -n "${REDIS_PASSWORD:-}" ]]; then
            if redis-cli -a "$REDIS_PASSWORD" PUBLISH "$REDIS_CHANNEL" "$alert_json" >/dev/null 2>&1; then
                redis_result=0
            fi
        else
            if redis-cli PUBLISH "$REDIS_CHANNEL" "$alert_json" >/dev/null 2>&1; then
                redis_result=0
            fi
        fi
        
        if [[ $redis_result -eq 0 ]]; then
            log "Alert published: $alert_type - PID $pid ($cmd) - ${rss_mb}MB (+${growth_mb}MB)"
        else
            log "WARNING: Failed to publish to Redis"
        fi
    else
        log "WARNING: redis-cli not found, alert not published"
    fi
}

# Initialize tracking file if it doesn't exist
init_track_file() {
    if [[ ! -f "$TRACK_FILE" ]]; then
        echo '{}' > "$TRACK_FILE"
        log "Initialized tracking file: $TRACK_FILE"
    fi
}

# Get current process list (>500MB)
get_large_processes() {
    # ps aux: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
    # RSS is in KB (column 6)
    ps aux | awk -v threshold="$THRESHOLD_MB" '
        NR > 1 && $6 > (threshold * 1024) {
            printf "%s|%s|%s|%s\n", $2, $6, $11, $0
        }
    ' | while IFS='|' read -r pid rss_kb cmd_full rest; do
        # Convert KB to MB
        local rss_mb
        rss_mb=$(echo "scale=1; $rss_kb / 1024" | bc -l | cut -d. -f1)
        
        # Extract command name (first word of command)
        local cmd
        cmd=$(echo "$cmd_full" | awk '{print $1}' | xargs basename 2>/dev/null || echo "$cmd_full")
        
        echo "$pid|$rss_mb|$cmd|$cmd_full"
    done
}

# Check for memory leaks
check_leaks() {
    local current_time
    current_time=$(date +%s)
    
    # Load tracking data
    local track_data
    track_data=$(cat "$TRACK_FILE" 2>/dev/null || echo '{}')
    
    # Process each large process
    get_large_processes | while IFS='|' read -r pid rss_mb cmd cmd_full; do
        # Get previous RSS for this PID
        local prev_rss_mb prev_timestamp
        prev_rss_mb=$(echo "$track_data" | jq -r ".[\"$pid\"].rss_mb // empty" 2>/dev/null || echo "")
        prev_timestamp=$(echo "$track_data" | jq -r ".[\"$pid\"].timestamp // empty" 2>/dev/null || echo "")
        
        if [[ -n "$prev_rss_mb" && -n "$prev_timestamp" ]]; then
            # Calculate time difference (minutes)
            local time_diff_min
            time_diff_min=$(echo "scale=1; ($current_time - $prev_timestamp) / 60" | bc -l)
            
            # Check if within leak window
            if (( $(echo "$time_diff_min <= $LEAK_WINDOW_MINUTES" | bc -l) )); then
                # Calculate growth
                local growth_mb
                growth_mb=$(echo "scale=1; $rss_mb - $prev_rss_mb" | bc -l | cut -d. -f1)
                
                # Check if growth exceeds threshold
                if [[ $growth_mb -ge $LEAK_THRESHOLD_MB ]]; then
                    log "LEAK DETECTED: PID $pid ($cmd) - ${rss_mb}MB (+${growth_mb}MB in ${time_diff_min}min)"
                    publish_alert \
                        "process_leak" \
                        "Memory leak detected: $cmd (PID $pid) grew ${growth_mb}MB in ${time_diff_min}min" \
                        "$pid" \
                        "$cmd" \
                        "$rss_mb" \
                        "$growth_mb"
                fi
            fi
        fi
        
        # Update tracking data
        track_data=$(echo "$track_data" | jq \
            --arg pid "$pid" \
            --argjson rss_mb "$rss_mb" \
            --argjson timestamp "$current_time" \
            --arg cmd "$cmd" \
            '.[$pid] = {rss_mb: $rss_mb, timestamp: $timestamp, cmd: $cmd}' 2>/dev/null || echo '{}')
    done
    
    # Save updated tracking data
    echo "$track_data" > "$TRACK_FILE"
    
    # Clean up old entries (older than 1 hour)
    local one_hour_ago
    one_hour_ago=$(($(date +%s) - 3600))
    track_data=$(echo "$track_data" | jq --argjson cutoff "$one_hour_ago" \
        'to_entries | map(select(.value.timestamp > $cutoff)) | from_entries' 2>/dev/null || echo '{}')
    echo "$track_data" > "$TRACK_FILE"
}

# Main function
main() {
    log "Process Watchdog starting..."
    
    # Initialize tracking file
    init_track_file
    
    # Check for leaks
    check_leaks
    
    # Count large processes
    local large_count
    large_count=$(get_large_processes | wc -l | tr -d ' ')
    log "Found $large_count processes >${THRESHOLD_MB}MB"
    
    log "Process Watchdog check complete"
}

# Run main function
main "$@"
