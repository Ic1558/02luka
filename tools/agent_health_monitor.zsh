#!/usr/bin/env zsh
# Agent Health Monitor - Detect crash loops and log bloat
# Runs every 5 minutes, publishes alerts to Redis

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Config
CRASH_LOOP_THRESHOLD=5
CRASH_LOOP_WINDOW_MINUTES=5
LOG_SIZE_THRESHOLD_MB=50
REDIS_CHANNEL="02luka:alerts:ram"
LOG_FILE="$HOME/02luka/logs/agent_health_monitor.log"
TRACK_FILE="/tmp/agent_health_track.json"
LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"
LOGS_DIR="$HOME/02luka/logs"

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
    local agent_name="${3:-}"
    local details="${4:-}"
    
    local alert_json
    alert_json=$(jq -n \
        --arg type "$alert_type" \
        --arg message "$message" \
        --arg agent "$agent_name" \
        --arg details "$details" \
        --arg timestamp "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        '{
            type: $type,
            severity: "critical",
            message: $message,
            agent: $agent,
            details: $details,
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
            log "Alert published: $alert_type - $agent_name"
        else
            log "WARNING: Failed to publish to Redis"
        fi
    else
        log "WARNING: redis-cli not found, alert not published"
    fi
}

# Initialize tracking file
init_track_file() {
    if [[ ! -f "$TRACK_FILE" ]]; then
        echo '{}' > "$TRACK_FILE"
        log "Initialized tracking file: $TRACK_FILE"
    fi
}

# Check for crash loops
check_crash_loops() {
    local current_time
    current_time=$(date +%s)
    
    # Load tracking data
    local track_data
    track_data=$(cat "$TRACK_FILE" 2>/dev/null || echo '{}')
    
    # Get all LaunchAgents with non-zero exit codes
    launchctl list | grep -E "Exit [^0]" | while read -r line; do
        local agent_name exit_code
        agent_name=$(echo "$line" | awk '{print $1}')
        exit_code=$(echo "$line" | awk '{print $3}')
        
        # Skip if no agent name
        [[ -z "$agent_name" ]] && continue
        
        # Get previous restart count and timestamp
        local prev_count prev_timestamp
        prev_count=$(echo "$track_data" | jq -r ".[\"$agent_name\"].restart_count // 0" 2>/dev/null || echo "0")
        prev_timestamp=$(echo "$track_data" | jq -r ".[\"$agent_name\"].timestamp // 0" 2>/dev/null || echo "0")
        
        # Calculate time difference (minutes)
        local time_diff_min
        time_diff_min=$(echo "scale=1; ($current_time - $prev_timestamp) / 60" | bc -l)
        
        # Reset count if outside window
        if (( $(echo "$time_diff_min > $CRASH_LOOP_WINDOW_MINUTES" | bc -l) )); then
            prev_count=0
            prev_timestamp=$current_time
        fi
        
        # Increment restart count
        local new_count
        new_count=$((prev_count + 1))
        
        # Update tracking data
        track_data=$(echo "$track_data" | jq \
            --arg agent "$agent_name" \
            --argjson count "$new_count" \
            --argjson timestamp "$current_time" \
            --argjson exit_code "$exit_code" \
            '.[$agent] = {restart_count: $count, timestamp: $timestamp, exit_code: $exit_code}' 2>/dev/null || echo '{}')
        
        # Check if crash loop detected
        if [[ $new_count -ge $CRASH_LOOP_THRESHOLD ]]; then
            log "CRASH LOOP DETECTED: $agent_name - $new_count restarts in ${time_diff_min}min (Exit: $exit_code)"
            publish_alert \
                "crash_loop" \
                "Crash loop detected: $agent_name restarted $new_count times in ${time_diff_min}min" \
                "$agent_name" \
                "Exit code: $exit_code, Restarts: $new_count"
        fi
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

# Check for log bloat
check_log_bloat() {
    if [[ ! -d "$LOGS_DIR" ]]; then
        return 0
    fi
    
    find "$LOGS_DIR" -name "*.log" -type f | while read -r logfile; do
        # Get file size in MB
        local size_mb
        size_mb=$(du -m "$logfile" 2>/dev/null | cut -f1 || echo "0")
        
        if [[ $size_mb -ge $LOG_SIZE_THRESHOLD_MB ]]; then
            local log_name
            log_name=$(basename "$logfile")
            log "LOG BLOAT DETECTED: $log_name - ${size_mb}MB (threshold: ${LOG_SIZE_THRESHOLD_MB}MB)"
            publish_alert \
                "log_bloat" \
                "Log file too large: $log_name (${size_mb}MB)" \
                "" \
                "File: $logfile, Size: ${size_mb}MB"
        fi
    done
}

# Main function
main() {
    log "Agent Health Monitor starting..."
    
    # Initialize tracking file
    init_track_file
    
    # Check for crash loops
    check_crash_loops
    
    # Check for log bloat
    check_log_bloat
    
    log "Agent Health Monitor check complete"
}

# Run main function
main "$@"
