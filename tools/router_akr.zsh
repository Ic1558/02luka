#!/usr/bin/env zsh
# Phase 15 – Autonomous Knowledge Router (AKR)
# Routes queries to appropriate agents based on intent classification
# Classification: Strategic Integration Patch (SIP)
# System: 02LUKA Cognitive Architecture
# Phase: 15 – Autonomous Knowledge Routing (AKR)
# Status: Active
# Maintainer: GG Core (02LUKA Automation)
# Version: v1.0.0
# Work Order: WO-251107-PHASE-15-AKR

set -euo pipefail

# Configuration
# Use LUKA_HOME if set, otherwise use $HOME/02luka
# Note: LUKA_HOME should point to the base directory, not g/ subdirectory
if [[ -n "${LUKA_HOME:-}" ]]; then
    BASE="$LUKA_HOME"
    # If LUKA_HOME points to g/, go up one level
    if [[ "$BASE" == */g ]]; then
        BASE="${BASE%/g}"
    fi
else
    BASE="$HOME/02luka"
fi
CONFIG="${BASE}/config/router_akr.yaml"
INTENT_MAP="${BASE}/config/nlp_command_map.yaml"
TELEMETRY_SINK="${BASE}/g/telemetry_unified/unified.jsonl"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[router_akr]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[router_akr]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[router_akr]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[router_akr]${NC} $*" >&2
}

# Function: Emit telemetry
emit_telemetry() {
    local event=$1
    shift
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Build JSON data from remaining arguments
    local json="{\"event\":\"$event\",\"ts\":\"$ts\",\"__source\":\"router_akr\",\"__normalized\":true"
    
    # Add data fields from remaining arguments (key:value format)
    if [[ $# -gt 0 ]]; then
        for arg in "$@"; do
            local key=$(echo "$arg" | cut -d: -f1)
            local val=$(echo "$arg" | cut -d: -f2-)
            # Remove quotes if present
            val=$(echo "$val" | sed 's/^"//;s/"$//')
            # Escape quotes in value
            val=$(echo "$val" | sed 's/"/\\"/g')
            json="$json,\"$key\":\"$val\""
        done
    fi
    
    json="$json}"
    
    mkdir -p "$(dirname "$TELEMETRY_SINK")"
    echo "$json" >> "$TELEMETRY_SINK"
}

# Function: Classify intent
classify_intent() {
    local query="$1"
    local intent=""
    local confidence=0.0
    local agent=""
    
    # Emit telemetry: classification start
    emit_telemetry "router.intent.classify_start" "query:\"$(echo "$query" | sed 's/"/\\"/g')\""
    
    # Check if intent map exists
    if [[ ! -f "$INTENT_MAP" ]]; then
        log_warn "Intent map not found: $INTENT_MAP, using fallback classification"
        agent="kim"
        confidence=0.3
        intent="unknown"
    else
        # Pattern matching against intent map
        if command -v yq >/dev/null 2>&1; then
            # Try to match against intent triggers
            local matched_intent=""
            while IFS= read -r intent_key; do
                if [[ -z "$intent_key" ]]; then
                    continue
                fi
                
                # Get triggers for this intent
                local triggers=$(yq eval ".intents.\"$intent_key\".triggers[]?" "$INTENT_MAP" 2>/dev/null || echo "")
                
                for trigger in $triggers; do
                    if echo "$query" | grep -iE "$trigger" >/dev/null 2>&1; then
                        matched_intent="$intent_key"
                        agent=$(yq eval ".intents.\"$intent_key\".route" "$INTENT_MAP" 2>/dev/null || echo "kim")
                        confidence=0.9
                        break 2
                    fi
                done
            done < <(yq eval '.intents | keys[]' "$INTENT_MAP" 2>/dev/null || echo "")
            
            if [[ -n "$matched_intent" ]]; then
                intent="$matched_intent"
            fi
        fi
        
        # Fallback: keyword matching
        if [[ -z "$intent" ]]; then
            if echo "$query" | grep -iE "(code|implement|function|class|write|create|build|add|fix|debug|test)" >/dev/null; then
                agent="andy"
                confidence=0.6
                intent="code.implement"
            elif echo "$query" | grep -iE "(explain|what|how|why|tell|describe|help)" >/dev/null; then
                agent="kim"
                confidence=0.6
                intent="chat.explain"
            else
                agent="kim"  # default
                confidence=0.3
                intent="chat.general"
            fi
        fi
    fi
    
    # Emit telemetry: classification complete
    emit_telemetry "router.intent.classified" \
        "intent:\"$intent\"" \
        "agent:\"$agent\"" \
        "confidence:\"$confidence\""
    
    echo "$agent:$confidence:$intent"
}

# Function: Select agent
select_agent() {
    local classification="$1"
    local agent=$(echo "$classification" | cut -d: -f1)
    local confidence=$(echo "$classification" | cut -d: -f2)
    local intent=$(echo "$classification" | cut -d: -f3)
    
    # Check confidence threshold
    local threshold=0.75
    if [[ -f "$CONFIG" ]] && command -v yq >/dev/null 2>&1; then
        threshold=$(yq eval '.router.intent_classifier.confidence_threshold' "$CONFIG" 2>/dev/null || echo "0.75")
    fi
    
    # Compare confidence with threshold (using awk for floating point comparison)
    local comparison=$(echo "$confidence $threshold" | awk '{if ($1 < $2) print 1; else print 0}')
    if [[ "$comparison" == "1" ]]; then
        # Low confidence - emit telemetry and use default
        emit_telemetry "router.query.ambiguous" \
            "confidence:\"$confidence\"" \
            "threshold:\"$threshold\""
        agent="kim"  # Default to Kim for clarification
    fi
    
    # Emit telemetry: agent selected
    emit_telemetry "router.agent.selected" \
        "agent:\"$agent\"" \
        "intent:\"$intent\"" \
        "confidence:\"$confidence\""
    
    echo "$agent"
}

# Main routing logic
main() {
    local query="${1:-}"
    
    if [[ -z "$query" ]]; then
        echo "Usage: $0 <query>" >&2
        echo "Routes queries to appropriate agents (andy, kim, system)" >&2
        exit 1
    fi
    
    # Start telemetry
    emit_telemetry "router.request.received" "query:\"$(echo "$query" | sed 's/"/\\"/g')\""
    
    # Classify intent
    local classification=$(classify_intent "$query")
    
    # Select agent
    local selected_agent=$(select_agent "$classification")
    
    # Return result
    echo "ROUTE_TO: $selected_agent"
    echo "CLASSIFICATION: $classification"
    
    # End telemetry
    emit_telemetry "router.request.completed" "agent:\"$selected_agent\""
    
    # Exit with success
    return 0
}

main "$@"
