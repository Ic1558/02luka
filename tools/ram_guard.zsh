#!/usr/bin/env zsh
# RAM Guard - Monitor swap/load/memory pressure
# Runs every 60s via LaunchAgent, publishes alerts to Redis

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Config
SWAP_WARNING=75
SWAP_CRITICAL=90
LOAD_WARNING=10
REDIS_CHANNEL="02luka:alerts:ram"
LOG_FILE="$HOME/02luka/logs/ram_guard.log"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Helper: Log with timestamp
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Helper: Publish alert to Redis
publish_alert() {
    local alert_type="$1"
    local severity="$2"
    local message="$3"
    local swap_pct="$4"
    local swap_used_gb="$5"
    local swap_total_gb="$6"
    local load_avg="$7"
    
    local alert_json
    alert_json=$(jq -n \
        --arg type "$alert_type" \
        --arg severity "$severity" \
        --arg message "$message" \
        --argjson swap_pct "$swap_pct" \
        --argjson swap_used_gb "$swap_used_gb" \
        --argjson swap_total_gb "$swap_total_gb" \
        --argjson load_avg "$load_avg" \
        --arg timestamp "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --argjson actions_taken '[]' \
        '{
            type: $type,
            severity: $severity,
            message: $message,
            swap_pct: $swap_pct,
            swap_used_gb: $swap_used_gb,
            swap_total_gb: $swap_total_gb,
            load_avg: $load_avg,
            timestamp: $timestamp,
            actions_taken: $actions_taken
        }')
    
    # Try to publish to Redis, but don't fail if Redis is down
    if command -v redis-cli >/dev/null 2>&1; then
        # Check for Redis password (from workspace rules: gggclukaic)
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
            log "Alert published to Redis: $alert_type (swap: ${swap_pct}%)"
        else
            log "WARNING: Failed to publish to Redis (Redis may be down or auth failed)"
        fi
    else
        log "WARNING: redis-cli not found, alert not published"
    fi
}

# Get swap usage (macOS)
get_swap_usage() {
    local swap_info
    swap_info=$(sysctl vm.swapusage 2>/dev/null || echo "")
    
    if [[ -z "$swap_info" ]]; then
        log "ERROR: Failed to get swap usage"
        return 1
    fi
    
    # Parse: vm.swapusage = total = 24576.00M  used = 1024.00M  free = 23552.00M
    local swap_total_mb swap_used_mb
    
    # Extract total (first number after "total =")
    swap_total_mb=$(echo "$swap_info" | sed -n 's/.*total = \([0-9.]*\)M.*/\1/p')
    
    # Extract used (first number after "used =")
    swap_used_mb=$(echo "$swap_info" | sed -n 's/.*used = \([0-9.]*\)M.*/\1/p')
    
    if [[ -z "$swap_total_mb" || -z "$swap_used_mb" ]]; then
        log "ERROR: Failed to parse swap usage: $swap_info"
        return 1
    fi
    
    # Convert MB to GB
    local swap_total_gb swap_used_gb
    swap_total_gb=$(echo "$swap_total_mb / 1024" | bc -l)
    swap_used_gb=$(echo "$swap_used_mb / 1024" | bc -l)
    
    # Calculate percentage
    local swap_pct
    swap_pct=$(echo "scale=1; ($swap_used_mb / $swap_total_mb) * 100" | bc -l | cut -d. -f1)
    
    echo "$swap_pct|$swap_used_gb|$swap_total_gb"
}

# Get load average
get_load_average() {
    local load_info
    load_info=$(sysctl vm.loadavg 2>/dev/null || echo "")
    
    if [[ -z "$load_info" ]]; then
        log "ERROR: Failed to get load average"
        return 1
    fi
    
    # Parse: vm.loadavg = { 1.23 2.45 3.67 }
    # Get 1-minute load (first number)
    local load_1min
    load_1min=$(echo "$load_info" | sed -n 's/.*{ \([0-9.]*\) .*/\1/p')
    
    if [[ -z "$load_1min" ]]; then
        log "ERROR: Failed to parse load average: $load_info"
        return 1
    fi
    
    echo "$load_1min"
}

# Main monitoring loop
main() {
    log "RAM Guard starting..."
    
    # Get swap usage
    local swap_data
    swap_data=$(get_swap_usage) || {
        log "ERROR: Failed to get swap usage, exiting"
        exit 1
    }
    
    local swap_pct swap_used_gb swap_total_gb
    IFS='|' read -r swap_pct swap_used_gb swap_total_gb <<< "$swap_data"
    
    # Get load average
    local load_avg
    load_avg=$(get_load_average) || {
        log "WARNING: Failed to get load average, continuing..."
        load_avg="0"
    }
    
    # Log current state
    log "Swap: ${swap_pct}% (${swap_used_gb}GB / ${swap_total_gb}GB), Load: ${load_avg}"
    
    # Check thresholds
    if [[ $swap_pct -ge $SWAP_CRITICAL ]]; then
        log "CRITICAL: Swap usage at ${swap_pct}% (threshold: ${SWAP_CRITICAL}%)"
        publish_alert \
            "ram_critical" \
            "critical" \
            "Swap usage critical: ${swap_pct}% (${swap_used_gb}GB / ${swap_total_gb}GB)" \
            "$swap_pct" \
            "$swap_used_gb" \
            "$swap_total_gb" \
            "$load_avg"
    elif [[ $swap_pct -ge $SWAP_WARNING ]]; then
        log "WARNING: Swap usage at ${swap_pct}% (threshold: ${SWAP_WARNING}%)"
        publish_alert \
            "ram_warning" \
            "warning" \
            "Swap usage high: ${swap_pct}% (${swap_used_gb}GB / ${swap_total_gb}GB)" \
            "$swap_pct" \
            "$swap_used_gb" \
            "$swap_total_gb" \
            "$load_avg"
    fi
    
    # Check load average
    if (( $(echo "$load_avg > $LOAD_WARNING" | bc -l) )); then
        log "WARNING: Load average high: ${load_avg} (threshold: ${LOAD_WARNING})"
        # Include load warning in swap alert if swap is also high
        if [[ $swap_pct -lt $SWAP_WARNING ]]; then
            publish_alert \
                "load_warning" \
                "warning" \
                "Load average high: ${load_avg}" \
                "$swap_pct" \
                "$swap_used_gb" \
                "$swap_total_gb" \
                "$load_avg"
        fi
    fi
    
    log "RAM Guard check complete"
}

# Run main function
main "$@"
