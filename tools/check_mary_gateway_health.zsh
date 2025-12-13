#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Mary Gateway v3 Router Health Check
# ═══════════════════════════════════════════════════════════════════════
# Checks LaunchAgent status, process, log activity, and inbox consumption
# Output: JSON health report
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

ROOT="${LUKA_SOT:-${HOME}/02luka}"
LOG_FILE="${ROOT}/g/telemetry/gateway_v3_router.log"
INBOX_DIR="${ROOT}/bridge/inbox/MAIN"
LAUNCHAGENT_NAME="com.02luka.mary-gateway-v3"

# ═══════════════════════════════════════════
# Health Check Functions
# ═══════════════════════════════════════════

check_launchagent_status() {
    if launchctl list | /usr/bin/grep -q "$LAUNCHAGENT_NAME"; then
        echo "RUNNING"
    else
        echo "STOPPED"
    fi
}

check_process_running() {
    if ps aux | /usr/bin/grep -v grep | /usr/bin/grep -q "gateway_v3_router\|mary.*router"; then
        echo "RUNNING"
    else
        echo "STOPPED"
    fi
}

check_log_activity() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "NO_LOG"
        return
    fi
    
    # Check last activity (last 5 minutes)
    last_line=$(tail -n 1 "$LOG_FILE" 2>/dev/null || echo "")
    if [[ -z "$last_line" ]]; then
        echo "STALE"
        return
    fi
    
    # Extract timestamp from log (if available)
    # For now, check if file was modified in last 5 minutes
    if [[ -f "$LOG_FILE" ]]; then
        mod_time=$(stat -f "%m" "$LOG_FILE" 2>/dev/null || echo "0")
        current_time=$(date +%s)
        diff=$((current_time - mod_time))
        
        if [[ $diff -lt 300 ]]; then
            echo "ACTIVE"
        else
            echo "STALE"
        fi
    else
        echo "STALE"
    fi
}

check_inbox_consumption() {
    if [[ ! -d "$INBOX_DIR" ]]; then
        echo "NO_INBOX"
        return
    fi
    
    # Count files in inbox
    file_count=$(find "$INBOX_DIR" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $file_count -eq 0 ]]; then
        echo "HEALTHY"
    elif [[ $file_count -lt 10 ]]; then
        echo "BACKLOG"
    else
        echo "STUCK"
    fi
}

get_backlog_count() {
    if [[ -d "$INBOX_DIR" ]]; then
        find "$INBOX_DIR" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

get_last_activity() {
    if [[ -f "$LOG_FILE" ]]; then
        stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ" "$LOG_FILE" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# ═══════════════════════════════════════════
# Main Health Check
# ═══════════════════════════════════════════

launchagent_status=$(check_launchagent_status)
process_status=$(check_process_running)
log_activity=$(check_log_activity)
inbox_consumption=$(check_inbox_consumption)
backlog_count=$(get_backlog_count)
last_activity=$(get_last_activity)

# Determine overall status
if [[ "$launchagent_status" == "RUNNING" && "$process_status" == "RUNNING" && "$log_activity" == "ACTIVE" ]]; then
    overall_status="HEALTHY"
elif [[ "$launchagent_status" == "STOPPED" && "$process_status" == "STOPPED" ]]; then
    overall_status="DOWN"
else
    overall_status="DEGRADED"
fi

# Generate recommendations
recommendations=()
if [[ "$launchagent_status" == "STOPPED" ]]; then
    recommendations+=("Start LaunchAgent: launchctl load ~/Library/LaunchAgents/${LAUNCHAGENT_NAME}.plist")
fi
if [[ "$process_status" == "STOPPED" ]]; then
    recommendations+=("Process not running - check LaunchAgent logs")
fi
if [[ "$log_activity" == "STALE" ]]; then
    recommendations+=("Log activity stale - check for errors in ${LOG_FILE}")
fi
if [[ "$inbox_consumption" == "STUCK" ]]; then
    recommendations+=("Inbox backlog high (${backlog_count} files) - check processor")
fi

# ═══════════════════════════════════════════
# Output JSON Report
# ═══════════════════════════════════════════

# Convert recommendations array to JSON array
if [[ ${#recommendations[@]} -eq 0 ]]; then
    recommendations_json="[]"
else
    recommendations_json="["
    local first=true
    for rec in "${recommendations[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            recommendations_json+=","
        fi
        # Escape quotes in recommendation text
        rec_escaped=$(echo "$rec" | sed 's/"/\\"/g')
        recommendations_json+="\"${rec_escaped}\""
    done
    recommendations_json+="]"
fi

cat <<EOF
{
  "status": "${overall_status}",
  "launchagent": "${launchagent_status}",
  "process": "${process_status}",
  "log_activity": "${log_activity}",
  "inbox_consumption": "${inbox_consumption}",
  "last_activity": "${last_activity}",
  "backlog_count": ${backlog_count},
  "recommendations": ${recommendations_json}
}
EOF

