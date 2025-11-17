#!/bin/zsh
# Agent Status - Unified health check for all 02luka agents
# Created: 2025-11-05
# Usage: $SOT/tools/agent_status.zsh

# SOT variable (PATH protocol compliance)
SOT="${SOT:-$HOME/02luka}"

setopt ERR_EXIT
set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║           02LUKA Agent Health Monitor                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if service is running
check_service() {
  local service=$1
  # Match exact service name at end of line (column 3)
  if launchctl list | awk '{print $3}' | grep -q "^${service}$"; then
    local exit_code=$(launchctl list | awk -v svc="$service" '$3 == svc {print $1}')
    local pid=$(launchctl list | awk -v svc="$service" '$3 == svc {print $2}')

    # Running process with actual PID (not 0)
    if [[ "$pid" =~ ^[1-9][0-9]*$ ]]; then
      echo -e "${GREEN}✅${NC} Running (PID: $pid)"
      return 0
    # PID=0 with exit="-" means loaded, waiting for trigger
    elif [[ "$pid" == "0" ]] && [[ "$exit_code" == "-" ]]; then
      echo -e "${GREEN}✅${NC} Loaded (waiting for trigger)"
      return 0
    # PID=0 with exit=0 means last run successful
    elif [[ "$pid" == "0" ]] && [[ "$exit_code" == "0" ]]; then
      echo -e "${GREEN}✅${NC} Success (last run: exit 0)"
      return 0
    # Both "-" means waiting for trigger (alternative state)
    elif [[ "$exit_code" == "-" ]] && [[ "$pid" == "-" ]]; then
      echo -e "${GREEN}✅${NC} Loaded (idle)"
      return 0
    # Just "-" in exit code means idle/waiting
    elif [[ "$exit_code" == "-" ]]; then
      echo -e "${YELLOW}⏸${NC}  Idle"
      return 1
    # Exit 0 with unknown PID state
    elif [[ "$exit_code" == "0" ]]; then
      echo -e "${GREEN}✅${NC} Success (exit: 0)"
      return 0
    # Any other exit code is a failure
    else
      echo -e "${RED}❌${NC} Failed (exit: $exit_code)"
      return 2
    fi
  else
    echo -e "${RED}❌${NC} Not loaded"
    return 3
  fi
}

# Get recent log activity
get_log_activity() {
  local logfile=$1
  if [[ -f "$logfile" ]]; then
    local last_line=$(tail -1 "$logfile" 2>/dev/null)
    if [[ -n "$last_line" ]]; then
      # Extract timestamp if present
      if [[ "$last_line" =~ \[([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
        local timestamp="${match[1]}"
        # Calculate time ago
        local now=$(date +%s)
        local log_time=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$timestamp" +%s 2>/dev/null || echo "0")
        if [[ "$log_time" != "0" ]]; then
          local diff=$((now - log_time))
          if [[ $diff -lt 60 ]]; then
            echo "${diff}s ago"
          elif [[ $diff -lt 3600 ]]; then
            echo "$((diff / 60))m ago"
          elif [[ $diff -lt 86400 ]]; then
            echo "$((diff / 3600))h ago"
          else
            echo "$((diff / 86400))d ago"
          fi
          return
        fi
      fi
    fi
  fi
  echo "N/A"
}

# Core Agents
echo "═══════════════════════════════════════════════════════════"
echo "🤖 Core Execution Agents"
echo "═══════════════════════════════════════════════════════════"

echo -n "WO Executor:         "
check_service "com.02luka.wo_executor"
echo "  Last activity:     $(get_log_activity "$SOT/logs/wo_executor.out.log")"
echo ""

echo -n "JSON WO Processor:   "
check_service "com.02luka.json_wo_processor"
echo "  Last activity:     $(get_log_activity "$SOT/logs/json_wo_processor.out.log")"
echo ""

# R&D Autopilot System
echo "═══════════════════════════════════════════════════════════"
echo "🚀 R&D Autopilot System"
echo "═══════════════════════════════════════════════════════════"

echo -n "Autopilot:           "
check_service "com.02luka.autopilot"
echo ""

echo -n "Local Truth Scanner: "
check_service "com.02luka.localtruth"
echo ""

echo -n "Autopilot Digest:    "
check_service "com.02luka.autopilot.digest"
echo ""

# Ollama Workers
echo "═══════════════════════════════════════════════════════════"
echo "🧠 AI Workers"
echo "═══════════════════════════════════════════════════════════"

echo -n "Ollama Bridge:       "
check_service "com.02luka.ollama-bridge"
echo ""

# Mary System
echo "═══════════════════════════════════════════════════════════"
echo "💼 Mary Agent System"
echo "═══════════════════════════════════════════════════════════"

echo -n "Agent Lisa:          "
check_service "com.02luka.agent.lisa"
echo ""

echo -n "Agent Mary:          "
check_service "com.02luka.agent.mary"
echo ""

echo -n "Mary Escalation:     "
check_service "com.02luka.mary.escalation"
echo ""

# Infrastructure
echo "═══════════════════════════════════════════════════════════"
echo "🔧 Infrastructure Services"
echo "═══════════════════════════════════════════════════════════"

echo -n "Librarian v2:        "
check_service "com.02luka.librarian.v2"
echo ""

echo -n "Context Monitor:     "
check_service "com.02luka.context.monitor"
echo ""

echo -n "Disk Monitor:        "
check_service "com.02luka.disk_monitor"
echo ""

echo -n "LLM Router:          "
check_service "com.02luka.llm-router"
echo ""

# Data Processing
echo "═══════════════════════════════════════════════════════════"
echo "📊 Data Processing"
echo "═══════════════════════════════════════════════════════════"

echo -n "Catalog Lite (30m):  "
check_service "com.02luka.catalog_lite_30m"
echo ""

echo -n "GG Agent:            "
check_service "com.02luka.gg_agent"
echo ""

echo -n "Tree Index (daily):  "
check_service "com.02luka.gg.treeindex.daily"
echo ""

echo -n "Meta Index (5m):     "
check_service "com.02luka.gg.metaindex.5m"
echo ""

# Sync Services
echo "═══════════════════════════════════════════════════════════"
echo "☁️  Sync & Backup Services"
echo "═══════════════════════════════════════════════════════════"

echo -n "NAS Sync (12h):      "
check_service "com.02luka.nas_sync_12h"
echo ""

echo -n "Daily Verify:        "
check_service "com.02luka.daily.verify"
echo ""

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📊 Summary"
echo "═══════════════════════════════════════════════════════════"

# Count statuses
total=$(launchctl list | grep "com.02luka" | wc -l | tr -d ' ')
running=$(launchctl list | grep "com.02luka" | awk '{print $2}' | grep -E '^[0-9]+$' | wc -l | tr -d ' ')
success=$(launchctl list | grep "com.02luka" | awk '{print $1}' | grep -c '^0$' || echo "0")
failed=$(launchctl list | grep "com.02luka" | awk '{print $1}' | grep -E '^[1-9]' | wc -l | tr -d ' ')

echo "Total agents:        $total"
echo "Running (with PID):  $running"
echo "Success (exit 0):    $success"
echo "Failed/Errored:      $failed"
echo ""

# Quick actions
echo "═══════════════════════════════════════════════════════════"
echo "🛠  Quick Actions"
echo "═══════════════════════════════════════════════════════════"
echo "  • View logs:      \$SOT/logs/"
echo "  • Autopilot:      \$SOT/tools/autopilot_status.zsh"
echo "  • Restart agent:  launchctl unload/load ~/Library/LaunchAgents/com.02luka.<service>.plist"
echo ""
