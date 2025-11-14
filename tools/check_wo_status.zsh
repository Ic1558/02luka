#!/usr/bin/env zsh
# WO Status Checker with Progress Bars and Colors
# Usage: ./tools/check_wo_status.zsh [--watch]

set -euo pipefail

WATCH_MODE=false
if [[ "${1:-}" == "--watch" ]]; then
  WATCH_MODE=true
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Progress bar function
progress_bar() {
  local progress=$1
  local width=20
  local filled=$(( progress * width / 100 ))
  local empty=$(( width - filled ))
  
  printf "["
  if [[ $progress -ge 75 ]]; then
    printf "${GREEN}"
  elif [[ $progress -ge 50 ]]; then
    printf "${YELLOW}"
  else
    printf "${RED}"
  fi
  
  printf "%${filled}s" | tr ' ' '█'
  printf "${GRAY}"
  printf "%${empty}s" | tr ' ' '░'
  printf "${NC}] %3d%%" "$progress"
}

check_wos() {
  if [[ $WATCH_MODE == true ]]; then
    clear
  fi
  
  echo ""
  echo -e "${BOLD}${BLUE}🔍 Work Order Status Check${NC}"
  echo -e "${GRAY}═══════════════════════════════════════════${NC}"
  echo -e "${GRAY}Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
  echo ""
  
  # Check CLC inbox
  echo -e "${BOLD}📥 CLC Inbox${NC} ${GRAY}(bridge/inbox/CLC/)${NC}"
  local clc_count=0
  if [[ -d "$HOME/02luka/bridge/inbox/CLC" ]]; then
    setopt null_glob
    for wo in "$HOME/02luka/bridge/inbox/CLC"/*.yaml "$HOME/02luka/bridge/inbox/CLC"/*.json; do
      if [[ -f "$wo" ]]; then
        local wo_id=$(basename "$wo")
        local wo_age=$(( ($(date +%s) - $(stat -f %m "$wo")) / 86400 ))
        local wo_status="pending"
        local title=""
        local progress=0
        
        # Try to extract data from YAML/JSON
        if [[ "$wo" == *.yaml ]]; then
          title=$(grep "^title:" "$wo" 2>/dev/null | sed 's/^title: *//' | tr -d '"' || echo "")
          wo_status=$(grep "^status:" "$wo" 2>/dev/null | sed 's/^status: *//' || echo "pending")
          progress=$(grep "^progress:" "$wo" 2>/dev/null | sed 's/^progress: *//' || echo "0")
        elif [[ "$wo" == *.json ]]; then
          title=$(jq -r '.title // .wo_title // ""' "$wo" 2>/dev/null || echo "")
          wo_status=$(jq -r '.status // "pending"' "$wo" 2>/dev/null || echo "pending")
          progress=$(jq -r '.progress // 0' "$wo" 2>/dev/null || echo "0")
        fi
        
        # Ensure progress is numeric
        if ! [[ "$progress" =~ ^[0-9]+$ ]]; then
          progress=0
        fi
        
        # Status symbol with color
        local symbol=""
        case "$wo_status" in
          complete|completed|done|finished)
            symbol="${GREEN}✅${NC}"
            progress=100
            ;;
          in_progress|processing|active)
            symbol="${YELLOW}⚙️ ${NC}"
            [[ $progress -eq 0 ]] && progress=50
            ;;
          paused)
            symbol="${YELLOW}⏸️ ${NC}"
            ;;
          blocked|failed|error)
            symbol="${RED}❌${NC}"
            ;;
          pending|open)
            symbol="${CYAN}⏳${NC}"
            ;;
          *)
            symbol="${GRAY}⏹️ ${NC}"
            ;;
        esac
        
        # Age color
        local age_color="${GREEN}"
        if [[ $wo_age -gt 7 ]]; then
          age_color="${RED}"
        elif [[ $wo_age -gt 3 ]]; then
          age_color="${YELLOW}"
        fi
        
        echo -e "  ${symbol} ${BOLD}${wo_id}${NC}"
        if [[ -n "$title" ]]; then
          echo -e "     ${GRAY}│${NC} ${title}"
        fi
        echo -e "     ${GRAY}│${NC} Status: ${wo_status} ${GRAY}│${NC} Age: ${age_color}${wo_age}d${NC}"
        echo -ne "     ${GRAY}└─${NC} "
        progress_bar $progress
        echo ""
        echo ""
        clc_count=$((clc_count + 1))
      fi
    done
  fi
  
  if [[ $clc_count -eq 0 ]]; then
    echo -e "  ${GRAY}(empty)${NC}"
  fi
  echo ""
  
  # Check ENTRY inbox
  echo -e "${BOLD}📬 ENTRY Inbox${NC} ${GRAY}(bridge/inbox/ENTRY/)${NC}"
  local entry_count=0
  if [[ -d "$HOME/02luka/bridge/inbox/ENTRY" ]]; then
    for wo in "$HOME/02luka/bridge/inbox/ENTRY"/*.yaml "$HOME/02luka/bridge/inbox/ENTRY"/*.json; do
      if [[ -f "$wo" ]]; then
        local wo_id=$(basename "$wo")
        local wo_age=$(( ($(date +%s) - $(stat -f %m "$wo")) / 86400 ))
        
        local age_color="${GREEN}"
        if [[ $wo_age -gt 7 ]]; then
          age_color="${RED}"
        elif [[ $wo_age -gt 3 ]]; then
          age_color="${YELLOW}"
        fi
        
        echo -e "  ${CYAN}⏳${NC} ${wo_id} ${GRAY}│${NC} Age: ${age_color}${wo_age}d${NC}"
        entry_count=$((entry_count + 1))
      fi
    done
  fi
  
  if [[ $entry_count -eq 0 ]]; then
    echo -e "  ${GRAY}(empty)${NC}"
  fi
  echo ""
  
  # Check followup state
  echo -e "${BOLD}📊 Followup State${NC} ${GRAY}(g/followup/state/)${NC}"
  local state_count=0
  if [[ -d "$HOME/02luka/g/followup/state" ]]; then
    state_count=$(find "$HOME/02luka/g/followup/state" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
  fi
  
  if [[ $state_count -gt 0 ]]; then
    echo -e "  ${GREEN}✓${NC} Total state files: ${BOLD}$state_count${NC}"
  else
    echo -e "  ${GRAY}○${NC} Total state files: ${GRAY}0${NC}"
  fi
  echo ""
  
  # Check LaunchAgents
  echo -e "${BOLD}🤖 WO Pipeline LaunchAgents${NC}"
  for agent in apply_patch_processor wo_executor json_wo_processor mary.dispatcher followup_tracker; do
    local agent_status=$(launchctl list | grep "com.02luka.$agent" | awk '{print $1}' || echo "not-found")
    local symbol=""
    local status_text=""
    local color=""
    
    if [[ "$agent_status" == "not-found" ]]; then
      symbol="○"
      status_text="not loaded"
      color="${GRAY}"
    elif [[ "$agent_status" == "-" ]] || [[ "$agent_status" == "0" ]]; then
      symbol="⏸️ "
      status_text="loaded (not running)"
      color="${YELLOW}"
    elif [[ "$agent_status" == "127" ]]; then
      symbol="❌"
      status_text="error (script missing)"
      color="${RED}"
    elif [[ "$agent_status" =~ ^[0-9]+$ ]]; then
      symbol="✅"
      status_text="running (PID: $agent_status)"
      color="${GREEN}"
    fi
    
    printf "  ${color}${symbol}${NC} com.02luka.%-25s ${color}%s${NC}\n" "$agent" "$status_text"
  done
  echo ""
  
  # Summary
  echo -e "${BOLD}📈 Summary${NC}"
  echo -e "${GRAY}─────────────────────────────────${NC}"
  echo -e "  CLC Inbox:    ${BOLD}${clc_count}${NC} WOs"
  echo -e "  ENTRY Inbox:  ${BOLD}${entry_count}${NC} WOs"
  echo -e "  State files:  ${BOLD}${state_count}${NC}"
  echo -e "  ${GRAY}─────────────────────────────────${NC}"
  echo -e "  Total pending: ${BOLD}${CYAN}$((clc_count + entry_count))${NC}"
  echo ""
  
  # Warnings
  if [[ $((clc_count + entry_count)) -gt 0 ]] && [[ $state_count -eq 0 ]]; then
    echo -e "${RED}⚠️  WARNING:${NC} WOs exist but no state files!"
    echo -e "   ${GRAY}→ This means WO processors are not working.${NC}"
    echo ""
  fi
  
  if [[ $clc_count -gt 5 ]]; then
    echo -e "${YELLOW}⚠️  NOTICE:${NC} High WO backlog (${clc_count} items)"
    echo -e "   ${GRAY}→ Consider reviewing WO processing pipeline.${NC}"
    echo ""
  fi
  
  if [[ $WATCH_MODE == true ]]; then
    echo -e "${GRAY}Press Ctrl+C to exit watch mode...${NC}"
  fi
}

if [[ $WATCH_MODE == true ]]; then
  while true; do
    check_wos
    sleep 5
  done
else
  check_wos
fi
