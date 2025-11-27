#!/usr/bin/env zsh
# OPAL V4 System Health Check Tool
# Created: 2025-11-27 by CLC Worker
# WO: WO-HEALTH-CHECK-0001 (Fixed v2)

setopt +o nomatch  # Prevent glob errors

echo "🔍 OPAL V4 Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ═══════════════════════════════════════════
# 1. Redis Check
# ═══════════════════════════════════════════
echo "▶ [1/5] Redis Ping"
if redis-cli -a gggclukaic ping 2>/dev/null | grep -q PONG; then
    echo "   ✅ Redis: PONG"
else
    echo "   ❌ Redis: NOT RESPONDING"
fi
echo ""

# ═══════════════════════════════════════════
# 2. OPAL API Check
# ═══════════════════════════════════════════
echo "▶ [2/5] Opal API"
API_RESPONSE=$(curl -s http://127.0.0.1:7001/api/budget 2>/dev/null || echo "FAILED")
if [[ "$API_RESPONSE" != "FAILED" && "$API_RESPONSE" != *"error"* ]]; then
    echo "   ✅ API: Running on :7001"
else
    echo "   ❌ API: NOT RESPONDING"
fi
echo ""

# ═══════════════════════════════════════════
# 3. LaunchAgents Check
# ═══════════════════════════════════════════
echo "▶ [3/5] LaunchAgents Status"
echo "   OPAL Pipeline Services:"

for agent in "shell-executor" "mary-bridge" "clc-worker"; do
    result=$(launchctl list 2>/dev/null | grep "$agent" || echo "")
    if [[ -n "$result" ]]; then
        pid=$(echo "$result" | awk '{print $1}')
        exit_code=$(echo "$result" | awk '{print $2}')
        if [[ "$pid" != "-" && "$exit_code" == "0" ]]; then
            echo "   ✅ $agent (PID: $pid)"
        elif [[ "$pid" != "-" ]]; then
            echo "   ⚠️  $agent (PID: $pid, exit: $exit_code)"
        else
            echo "   ❌ $agent (not running, last exit: $exit_code)"
        fi
    else
        echo "   ⚪ $agent (not loaded)"
    fi
done
echo ""

# ═══════════════════════════════════════════
# 4. Latest CLC Worker ACKs
# ═══════════════════════════════════════════
echo "▶ [4/5] Latest CLC Worker ACKs"
ACK_DIR="$HOME/02luka/bridge/outbox/LIAM"
if [[ -d "$ACK_DIR" ]]; then
    ACK_COUNT=$(find "$ACK_DIR" -name "*.ack.json" 2>/dev/null | wc -l | tr -d ' ')
    echo "   Total ACKs: $ACK_COUNT"
    echo "   Recent:"
    find "$ACK_DIR" -name "*.ack.json" -print 2>/dev/null | xargs ls -t 2>/dev/null | head -3 | while read f; do
        echo "   • $(basename $f)"
    done
else
    echo "   ⚠️  ACK directory not found"
fi
echo ""

# ═══════════════════════════════════════════
# 5. Bridge Inbox Status
# ═══════════════════════════════════════════
echo "▶ [5/5] Bridge Inbox Status"
ENTRY_COUNT=$(find "$HOME/02luka/bridge/inbox/ENTRY" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
CLC_COUNT=$(find "$HOME/02luka/bridge/inbox/CLC" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
echo "   📥 ENTRY inbox: ${ENTRY_COUNT:-0} pending"
echo "   📥 CLC inbox: ${CLC_COUNT:-0} pending"
echo ""

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏁 Health Check Complete"
echo ""
