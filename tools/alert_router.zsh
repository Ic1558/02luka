#!/usr/bin/env zsh
# Alert Router - Route Redis alerts to macOS notifications and Telegram
# Subscribes to Redis channel 02luka:alerts:ram and routes alerts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Config
REDIS_CHANNEL="02luka:alerts:ram"
LOG_FILE="$HOME/02luka/logs/alert_router.log"
TELEGRAM_ENABLED=false

# Check for Telegram config
if [[ -f "$HOME/02luka/config/kim.env" ]]; then
    if grep -q "TELEGRAM_BOT_TOKEN=" "$HOME/02luka/config/kim.env" 2>/dev/null; then
        TELEGRAM_ENABLED=true
    fi
fi

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Helper: Log with timestamp
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Helper: Send macOS notification
send_macos_notification() {
    local title="$1"
    local message="$2"
    
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
    log "macOS notification sent: $title - $message"
}

# Helper: Send Telegram message (if configured)
send_telegram() {
    local message="$1"
    
    if [[ "$TELEGRAM_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Try to use existing Telegram bridge if available
    # For now, just log that Telegram would be sent
    log "Telegram notification (would send): $message"
    # TODO: Integrate with existing Telegram bridge
}

# Helper: Route alert based on severity
route_alert() {
    local alert_json="$1"
    
    # Parse alert JSON
    local alert_type severity message
    alert_type=$(echo "$alert_json" | jq -r '.type // "unknown"' 2>/dev/null || echo "unknown")
    severity=$(echo "$alert_json" | jq -r '.severity // "warning"' 2>/dev/null || echo "warning")
    message=$(echo "$alert_json" | jq -r '.message // "Alert"' 2>/dev/null || echo "Alert")
    
    # Format title
    local title
    case "$alert_type" in
        ram_critical|ram_warning)
            local swap_pct
            swap_pct=$(echo "$alert_json" | jq -r '.swap_pct // "?"' 2>/dev/null || echo "?")
            title="02luka RAM Alert (${swap_pct}%)"
            ;;
        process_leak)
            local cmd
            cmd=$(echo "$alert_json" | jq -r '.command // "unknown"' 2>/dev/null || echo "unknown")
            title="02luka Process Leak: $cmd"
            ;;
        crash_loop)
            local agent
            agent=$(echo "$alert_json" | jq -r '.agent // "unknown"' 2>/dev/null || echo "unknown")
            title="02luka Crash Loop: $agent"
            ;;
        log_bloat)
            title="02luka Log Bloat"
            ;;
        *)
            title="02luka System Alert"
            ;;
    esac
    
    # Route based on severity
    case "$severity" in
        critical)
            # CRITICAL: macOS + Telegram
            send_macos_notification "$title" "$message"
            send_telegram "🚨 CRITICAL: $title - $message"
            ;;
        warning)
            # WARNING: macOS only
            send_macos_notification "$title" "$message"
            ;;
        *)
            # Other: macOS only
            send_macos_notification "$title" "$message"
            ;;
    esac
}

# Main function: Subscribe to Redis and route alerts
main() {
    log "Alert Router starting..."
    log "Subscribing to Redis channel: $REDIS_CHANNEL"
    log "Telegram enabled: $TELEGRAM_ENABLED"
    
    # Subscribe to Redis channel
    if command -v redis-cli >/dev/null 2>&1; then
        local redis_cmd="redis-cli"
        if [[ -n "${REDIS_PASSWORD:-}" ]]; then
            redis_cmd="redis-cli -a \"$REDIS_PASSWORD\""
        fi
        
        # Subscribe and process messages
        eval "$redis_cmd SUBSCRIBE $REDIS_CHANNEL" 2>/dev/null | while read -r line; do
            # Redis SUBSCRIBE output format:
            # *3
            # $7
            # message
            # $3
            # $XX
            # {"json":"data"}
            
            # Skip non-message lines
            if [[ "$line" != "message" ]]; then
                continue
            fi
            
            # Read the channel name (skip it)
            read -r channel_line
            
            # Read the actual message
            read -r alert_json
            
            # Route the alert
            route_alert "$alert_json"
        done
    else
        log "ERROR: redis-cli not found, cannot subscribe to alerts"
        exit 1
    fi
}

# Run main function
main "$@"
