#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# OPAL V4 Health Check v2 - Production Observability Tool
# ═══════════════════════════════════════════════════════════════════════
# Created: 2025-11-27 by CLC Worker
# WO: WO-HEALTH-CHECK-V2-0001
# Features:
#   - Latency metrics (API, Redis, Workers)
#   - Queue/backlog depth monitoring
#   - LaunchAgent restart detection
#   - Dual output: Text + JSON
#   - Auto-restart hooks (disabled by default)
# ═══════════════════════════════════════════════════════════════════════

setopt +o nomatch

# ═══════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════
ROOT="${HOME}/02luka"
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')
OUTPUT_JSON="$ROOT/g/telemetry/health_check_latest.json"
OUTPUT_LOG="$ROOT/g/telemetry/health_check.log"
REDIS_PASS="gggclukaic"
API_HOST="127.0.0.1"
API_PORT="7001"

# Auto-restart settings (DISABLED by default)
AUTO_RESTART_ENABLED=false

# Thresholds
LATENCY_WARN_MS=500
LATENCY_CRIT_MS=2000
BACKLOG_WARN=10
BACKLOG_CRIT=50

# ═══════════════════════════════════════════
# JSON Builder
# ═══════════════════════════════════════════
declare -A JSON_DATA
JSON_CHECKS=()
OVERALL_STATUS="healthy"
ISSUES=()

add_check() {
    local name="$1"
    local check_status="$2"
    local latency_ms="$3"
    local details="$4"
    
    JSON_CHECKS+=("{\"name\":\"$name\",\"status\":\"$check_status\",\"latency_ms\":$latency_ms,\"details\":\"$details\"}")
    
    if [[ "$check_status" == "critical" ]]; then
        OVERALL_STATUS="critical"
        ISSUES+=("$name: $details")
    elif [[ "$check_status" == "warning" && "$OVERALL_STATUS" != "critical" ]]; then
        OVERALL_STATUS="warning"
        ISSUES+=("$name: $details")
    fi
}

# ═══════════════════════════════════════════
# Header
# ═══════════════════════════════════════════
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║          🔍 OPAL V4 Health Check v2 - Observability               ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo "📅 Timestamp: $TIMESTAMP"
echo "🔧 Auto-restart: $(if $AUTO_RESTART_ENABLED; then echo 'ENABLED'; else echo 'disabled'; fi)"
echo ""

# ═══════════════════════════════════════════
# 1. Redis Health + Latency
# ═══════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ [1/6] Redis Health                                              │"
echo "└─────────────────────────────────────────────────────────────────┘"

REDIS_START=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
REDIS_PING=$(redis-cli -a "$REDIS_PASS" ping 2>/dev/null)
REDIS_END=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
REDIS_LATENCY=$(echo "($REDIS_END - $REDIS_START) * 1000" | bc | cut -d'.' -f1)

if [[ "$REDIS_PING" == "PONG" ]]; then
    REDIS_INFO=$(redis-cli -a "$REDIS_PASS" info memory 2>/dev/null | grep used_memory_human | cut -d: -f2 | tr -d '\r')
    REDIS_CLIENTS=$(redis-cli -a "$REDIS_PASS" info clients 2>/dev/null | grep connected_clients | cut -d: -f2 | tr -d '\r')
    
    if [[ "$REDIS_LATENCY" -gt "$LATENCY_CRIT_MS" ]]; then
        echo "   ⚠️  Redis: SLOW (${REDIS_LATENCY}ms > ${LATENCY_CRIT_MS}ms)"
        add_check "redis" "warning" "$REDIS_LATENCY" "High latency"
    else
        echo "   ✅ Redis: PONG"
    fi
    echo "   📊 Latency: ${REDIS_LATENCY}ms | Memory: ${REDIS_INFO:-N/A} | Clients: ${REDIS_CLIENTS:-N/A}"
    [[ -z "${REDIS_LATENCY}" || "$REDIS_LATENCY" -le "$LATENCY_CRIT_MS" ]] && add_check "redis" "healthy" "${REDIS_LATENCY:-0}" "OK"
else
    echo "   ❌ Redis: NOT RESPONDING"
    add_check "redis" "critical" "0" "Connection failed"
fi
echo ""

# ═══════════════════════════════════════════
# 2. OPAL API Health + Latency
# ═══════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ [2/6] OPAL API Health                                           │"
echo "└─────────────────────────────────────────────────────────────────┘"

API_RESULT=$(curl -s -w "\n%{time_total}" "http://${API_HOST}:${API_PORT}/api/budget" 2>/dev/null)
API_BODY=$(echo "$API_RESULT" | head -n1)
API_TIME=$(echo "$API_RESULT" | tail -n1)
API_LATENCY=$(echo "$API_TIME * 1000" | bc | cut -d'.' -f1)

if [[ -n "$API_BODY" && "$API_BODY" != *"error"* && "$API_BODY" != *"Failed"* ]]; then
    if [[ "$API_LATENCY" -gt "$LATENCY_CRIT_MS" ]]; then
        echo "   ⚠️  API: SLOW (${API_LATENCY}ms > ${LATENCY_CRIT_MS}ms)"
        add_check "opal_api" "warning" "$API_LATENCY" "High latency"
    else
        echo "   ✅ API: Running on :${API_PORT}"
        add_check "opal_api" "healthy" "$API_LATENCY" "OK"
    fi
    echo "   📊 Latency: ${API_LATENCY}ms"
else
    echo "   ❌ API: NOT RESPONDING"
    add_check "opal_api" "critical" "0" "Connection failed"
fi
echo ""

# ═══════════════════════════════════════════
# 3. LaunchAgents Status + Restart Detection
# ═══════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ [3/6] LaunchAgents Status                                       │"
echo "└─────────────────────────────────────────────────────────────────┘"

AGENTS=("shell-executor" "mary-bridge" "clc-worker")
typeset -A AGENT_STATUS_MAP

for agent in "${AGENTS[@]}"; do
    result=$(launchctl list 2>/dev/null | grep "$agent" || echo "")
    if [[ -n "$result" ]]; then
        pid=$(echo "$result" | awk '{print $1}')
        exit_code=$(echo "$result" | awk '{print $2}')
        
        if [[ "$pid" != "-" && "$exit_code" == "0" ]]; then
            echo "   ✅ $agent (PID: $pid)"
            add_check "agent_$agent" "healthy" "0" "Running"
            AGENT_STATUS_MAP["$agent"]="running"
        elif [[ "$pid" != "-" ]]; then
            echo "   ⚠️  $agent (PID: $pid, last exit: $exit_code)"
            add_check "agent_$agent" "warning" "0" "Exit code $exit_code"
            AGENT_STATUS_MAP["$agent"]="warning"
        else
            echo "   ❌ $agent (not running, last exit: $exit_code)"
            add_check "agent_$agent" "critical" "0" "Not running"
            AGENT_STATUS_MAP["$agent"]="stopped"
            
            # Auto-restart hook (disabled by default)
            if $AUTO_RESTART_ENABLED; then
                echo "   🔄 Auto-restarting $agent..."
                launchctl start "com.02luka.$agent" 2>/dev/null
            fi
        fi
    else
        echo "   ⚪ $agent (not loaded)"
        add_check "agent_$agent" "critical" "0" "Not loaded"
        AGENT_STATUS_MAP["$agent"]="not_loaded"
    fi
done
echo ""

# ═══════════════════════════════════════════
# 4. Queue/Backlog Depth
# ═══════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ [4/6] Queue & Backlog Status                                    │"
echo "└─────────────────────────────────────────────────────────────────┘"

# Redis pub/sub channels
SHELL_QUEUE=$(redis-cli -a "$REDIS_PASS" PUBSUB NUMSUB shell 2>/dev/null | tail -1 || echo "0")
WO_QUEUE=$(redis-cli -a "$REDIS_PASS" PUBSUB NUMSUB "wo:incoming:opal" 2>/dev/null | tail -1 || echo "0")

echo "   📡 Redis Channels:"
echo "      • shell subscribers: ${SHELL_QUEUE:-0}"
echo "      • wo:incoming:opal subscribers: ${WO_QUEUE:-0}"

# Bridge inbox backlog (exclude archive directories)
ENTRY_BACKLOG=$(find "$ROOT/bridge/inbox/ENTRY" -maxdepth 1 -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
CLC_BACKLOG=$(find "$ROOT/bridge/inbox/CLC" -maxdepth 1 -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')

echo "   📥 Bridge Inbox Backlog:"

if [[ "$ENTRY_BACKLOG" -gt "$BACKLOG_CRIT" ]]; then
    echo "      • ENTRY: ${ENTRY_BACKLOG} ❌ (> $BACKLOG_CRIT critical)"
    add_check "backlog_entry" "critical" "0" "$ENTRY_BACKLOG items"
elif [[ "$ENTRY_BACKLOG" -gt "$BACKLOG_WARN" ]]; then
    echo "      • ENTRY: ${ENTRY_BACKLOG} ⚠️ (> $BACKLOG_WARN warning)"
    add_check "backlog_entry" "warning" "0" "$ENTRY_BACKLOG items"
else
    echo "      • ENTRY: ${ENTRY_BACKLOG} ✅"
    add_check "backlog_entry" "healthy" "0" "$ENTRY_BACKLOG items"
fi

if [[ "$CLC_BACKLOG" -gt "$BACKLOG_CRIT" ]]; then
    echo "      • CLC: ${CLC_BACKLOG} ❌ (> $BACKLOG_CRIT critical)"
    add_check "backlog_clc" "critical" "0" "$CLC_BACKLOG items"
elif [[ "$CLC_BACKLOG" -gt "$BACKLOG_WARN" ]]; then
    echo "      • CLC: ${CLC_BACKLOG} ⚠️ (> $BACKLOG_WARN warning)"
    add_check "backlog_clc" "warning" "0" "$CLC_BACKLOG items"
else
    echo "      • CLC: ${CLC_BACKLOG} ✅"
    add_check "backlog_clc" "healthy" "0" "$CLC_BACKLOG items"
fi
echo ""

# ═══════════════════════════════════════════
# 5. Recent Activity
# ═══════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ [5/6] Recent Activity                                           │"
echo "└─────────────────────────────────────────────────────────────────┘"

ACK_DIR="$ROOT/bridge/outbox/LIAM"
if [[ -d "$ACK_DIR" ]]; then
    ACK_COUNT=$(find "$ACK_DIR" -name "*.ack.json" 2>/dev/null | wc -l | tr -d ' ')
    RECENT_ACKS=$(find "$ACK_DIR" -name "*.ack.json" -mmin -60 2>/dev/null | wc -l | tr -d ' ')
    echo "   📊 Total ACKs: $ACK_COUNT | Last hour: $RECENT_ACKS"
    echo "   📄 Latest 3:"
    find "$ACK_DIR" -name "*.ack.json" -print 2>/dev/null | xargs ls -t 2>/dev/null | head -3 | while read f; do
        echo "      • $(basename $f)"
    done
else
    echo "   ⚠️  ACK directory not found"
fi
echo ""

# ═══════════════════════════════════════════
# 6. System Resources
# ═══════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ [6/6] System Resources                                          │"
echo "└─────────────────────────────────────────────────────────────────┘"

# CPU Load
LOAD=$(uptime | awk -F'load averages:' '{print $2}' | xargs)
echo "   📈 Load Average: $LOAD"

# Memory
MEM_FREE=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
MEM_INACTIVE=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
TOTAL_FREE=$(( (MEM_FREE + MEM_INACTIVE) * 4096 / 1024 / 1024 ))
echo "   💾 Free Memory: ~${TOTAL_FREE} MB"

# Disk
DISK_FREE=$(df -h "$ROOT" 2>/dev/null | tail -1 | awk '{print $4}')
echo "   💿 Disk Free (02luka): $DISK_FREE"
echo ""

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════
echo "╔═══════════════════════════════════════════════════════════════════╗"
if [[ "$OVERALL_STATUS" == "healthy" ]]; then
    echo "║  ✅ OVERALL STATUS: HEALTHY                                       ║"
elif [[ "$OVERALL_STATUS" == "warning" ]]; then
    echo "║  ⚠️  OVERALL STATUS: WARNING                                       ║"
else
    echo "║  ❌ OVERALL STATUS: CRITICAL                                       ║"
fi
echo "╚═══════════════════════════════════════════════════════════════════╝"

if [[ ${#ISSUES[@]} -gt 0 ]]; then
    echo ""
    echo "📋 Issues Found:"
    for issue in "${ISSUES[@]}"; do
        echo "   • $issue"
    done
fi
echo ""

# ═══════════════════════════════════════════
# Generate JSON Output
# ═══════════════════════════════════════════
CHECKS_JSON=$(IFS=,; echo "${JSON_CHECKS[*]}")

cat > "$OUTPUT_JSON" << EOF
{
  "timestamp": "$TIMESTAMP",
  "version": "2.0",
  "overall_status": "$OVERALL_STATUS",
  "auto_restart_enabled": $AUTO_RESTART_ENABLED,
  "checks": [$CHECKS_JSON],
  "metrics": {
    "redis_latency_ms": ${REDIS_LATENCY:-0},
    "api_latency_ms": ${API_LATENCY:-0},
    "entry_backlog": $ENTRY_BACKLOG,
    "clc_backlog": $CLC_BACKLOG,
    "total_acks": ${ACK_COUNT:-0},
    "recent_acks_1h": ${RECENT_ACKS:-0},
    "free_memory_mb": $TOTAL_FREE,
    "disk_free": "$DISK_FREE"
  },
  "agents": {
    "shell_executor": "${AGENT_STATUS_MAP["shell-executor"]:-unknown}",
    "mary_bridge": "${AGENT_STATUS_MAP["mary-bridge"]:-unknown}",
    "clc_worker": "${AGENT_STATUS_MAP["clc-worker"]:-unknown}"
  }
}
EOF

echo "📄 JSON output: $OUTPUT_JSON"
echo "📝 Log appended: $OUTPUT_LOG"
echo "$TIMESTAMP | $OVERALL_STATUS | Redis:${REDIS_LATENCY:-0}ms API:${API_LATENCY:-0}ms ENTRY:$ENTRY_BACKLOG CLC:$CLC_BACKLOG" >> "$OUTPUT_LOG"
echo ""
