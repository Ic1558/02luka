#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Governance v5 Production Monitoring Script
# ═══════════════════════════════════════════════════════════════════════
# Monitors v5 stack usage in production:
# - Gateway v3 Router activity
# - WO processing statistics
# - Lane distribution
# - Error rates
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

ROOT="${LUKA_SOT:-${HOME}/02luka}"
LOG_FILE="${ROOT}/g/telemetry/gateway_v3_router.log"
MAIN_INBOX="${ROOT}/bridge/inbox/MAIN"
CLC_INBOX="${ROOT}/bridge/inbox/CLC"
PROCESSED="${ROOT}/bridge/processed/MAIN"
ERROR="${ROOT}/bridge/error/MAIN"

# ═══════════════════════════════════════════
# Monitoring Functions
# ═══════════════════════════════════════════

check_v5_activity() {
    local hours=${1:-24}
    local since=$(date -v-${hours}H +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -d "${hours} hours ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || echo "")
    
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "NO_LOG"
        return
    fi
    
    # Count v5 processing events within the time window
    # Use Python to parse timestamps and filter by time window
    local v5_count=0
    local legacy_count=0
    
    if [[ -n "$since" ]]; then
        # Filter by timestamp if since is available
        python3 << PYEOF
import json
import sys
from datetime import datetime

log_file = "$LOG_FILE"
since_str = "$since"
hours = $hours

try:
    since_dt = datetime.fromisoformat(since_str.replace('Z', '+00:00'))
except:
    since_dt = None

v5_count = 0
legacy_count = 0

try:
    with open(log_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                ts_str = data.get('ts', '')
                if ts_str and since_dt:
                    try:
                        ts_dt = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                        if ts_dt < since_dt:
                            continue  # Skip entries before time window
                    except:
                        pass  # If timestamp parsing fails, include entry (safer)
                
                action = data.get('action', '')
                if action == 'process_v5':
                    v5_count += 1
                elif action == 'route':
                    legacy_count += 1
            except json.JSONDecodeError:
                continue
except FileNotFoundError:
    pass

print(f"v5:{v5_count},legacy:{legacy_count}")
PYEOF
    else
        # Fallback: count all entries if timestamp filtering unavailable
        if /usr/bin/grep -q "process_v5" "$LOG_FILE" 2>/dev/null; then
            v5_count=$(/usr/bin/grep "process_v5" "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
        fi
        
        if /usr/bin/grep -q '"action":"route"' "$LOG_FILE" 2>/dev/null; then
            legacy_count=$(/usr/bin/grep '"action":"route"' "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
        fi
        
        echo "v5:${v5_count},legacy:${legacy_count}"
    fi
}

check_lane_distribution() {
    # Count operations by lane from telemetry
    # Sum up strict_ops, local_ops, rejected_ops from all v5 processing entries
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "{}"
        return
    fi
    
    # Use Python to parse JSON and sum values
    python3 << PYEOF
import json
import sys

strict_ops = 0
local_ops = 0
rejected_ops = 0

log_file = "$LOG_FILE"

try:
    with open(log_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                if data.get('action') == 'process_v5':
                    strict_ops += data.get('strict_ops', 0)
                    local_ops += data.get('local_ops', 0)
                    rejected_ops += data.get('rejected_ops', 0)
            except json.JSONDecodeError:
                continue
except FileNotFoundError:
    pass

print(f'{{"strict":{strict_ops},"local":{local_ops},"rejected":{rejected_ops}}}')
PYEOF
}

check_inbox_backlog() {
    # Count only YAML files, not directories
    local main_count=0
    local clc_count=0
    
    if [[ -d "$MAIN_INBOX" ]]; then
        main_count=$(find "$MAIN_INBOX" -maxdepth 1 -name "*.yaml" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    if [[ -d "$CLC_INBOX" ]]; then
        # Count YAML files directly in CLC inbox (not in subdirectories)
        clc_count=$(find "$CLC_INBOX" -maxdepth 1 -name "*.yaml" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    echo "{\"main\":${main_count},\"clc\":${clc_count}}"
}

check_error_rate() {
    # Count only YAML files in processed/ and error/ directories
    local processed_count=0
    local error_count=0
    
    if [[ -d "$PROCESSED" ]]; then
        processed_count=$(find "$PROCESSED" -maxdepth 1 -name "*.yaml" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    if [[ -d "$ERROR" ]]; then
        error_count=$(find "$ERROR" -maxdepth 1 -name "*.yaml" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    local total=$((processed_count + error_count))
    local error_rate=0
    
    if [[ $total -gt 0 ]]; then
        error_rate=$((error_count * 100 / total))
    fi
    
    echo "{\"processed\":${processed_count},\"errors\":${error_count},\"error_rate\":${error_rate}}"
}

# ═══════════════════════════════════════════
# Main
# ═══════════════════════════════════════════

main() {
    local output_format="${1:-json}"
    
    local v5_activity=$(check_v5_activity 24)
    local lane_dist=$(check_lane_distribution)
    local inbox_backlog=$(check_inbox_backlog)
    local error_stats=$(check_error_rate)
    
    if [[ "$output_format" == "json" ]]; then
        cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "v5_activity_24h": "$v5_activity",
  "lane_distribution": $lane_dist,
  "inbox_backlog": $inbox_backlog,
  "error_stats": $error_stats,
  "status": "operational"
}
EOF
    else
        echo "📊 Governance v5 Production Monitoring"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Activity (24h): $v5_activity"
        echo "Lane Distribution: $lane_dist"
        echo "Inbox Backlog: $inbox_backlog"
        echo "Error Stats: $error_stats"
    fi
}

main "$@"

