#!/usr/bin/env bash
# Router AKR - Phase 15 Intent-based Agent Router
# Handles intelligent routing between agents based on intent classification
# Compatible with both bash and zsh
set -euo pipefail

# ============================================================================
# Constants and Configuration
# ============================================================================
BASE="${LUKA_HOME:-$HOME/02luka}"
ROUTER_CONFIG="${BASE}/config/router_akr.yaml"
ANDY_CONFIG="${BASE}/config/agents/andy.yaml"
KIM_CONFIG="${BASE}/config/agents/kim.yaml"
TELEMETRY_SINK="${BASE}/g/telemetry_unified/unified.jsonl"

VERSION="1.0.0"
PHASE="15"
WORK_ORDER="WO-251107-PHASE-15-AKR"

# Global state
DRY_RUN=0
VERBOSE=0
HOP_COUNT=0
MAX_HOPS=3
DELEGATION_CHAIN=""

# ============================================================================
# Utility Functions
# ============================================================================

log_error() {
  echo "ERROR: $*" >&2
}

log_warn() {
  echo "WARN: $*" >&2
}

log_info() {
  [[ $VERBOSE -eq 1 ]] && echo "INFO: $*" >&2
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <subcommand> [options]

Subcommands:
  route       Route a request to appropriate agent
  delegate    Handle delegation between agents
  dry-run     Simulate routing without execution
  selftest    Run internal self-test

Options:
  --json <json>       JSON input (required for route/delegate)
  --file <path>       Path to JSON file
  --from <agent>      Source agent (for delegate)
  --to <agent>        Target agent (for delegate)
  --intent <intent>   Intent classification
  --text <text>       Request text
  --verbose           Enable verbose logging
  --help              Show this help

Examples:
  # Route a request
  $0 route --json '{"agent":"kim","intent":"code.fix","text":"Fix the bug"}'

  # Delegate from Kim to Andy
  $0 delegate --from kim --to andy --intent code.implement --text "Create function"

  # Dry-run mode
  $0 --dry-run --json '{"agent":"kim","intent":"code.fix","text":"แก้บั๊ก ci แคช"}'

  # Run selftest
  $0 selftest

EOF
  exit 0
}

# ============================================================================
# Telemetry Functions
# ============================================================================

emit_telemetry() {
  local event="$1"
  shift
  local extra_fields="$*"

  if [[ ! -d "$(dirname "${TELEMETRY_SINK}")" ]]; then
    mkdir -p "$(dirname "${TELEMETRY_SINK}")"
  fi

  local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build JSON object
  local json="{\"event\":\"${event}\",\"ts\":\"${ts}\",\"__source\":\"router_akr\",\"__normalized\":true"

  if [[ -n "$extra_fields" ]]; then
    json="${json},${extra_fields}"
  fi

  json="${json}}"

  echo "$json" >> "${TELEMETRY_SINK}"
  log_info "Telemetry: $event"
}

# ============================================================================
# Configuration Loading
# ============================================================================

load_config() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    log_warn "Config file not found: $config_file"
    return 1
  fi

  # Check if yq is available and is the right version (mikefarah's yq)
  if command -v yq &>/dev/null; then
    if yq --version 2>&1 | grep -q "mikefarah"; then
      return 0
    else
      log_info "yq is not mikefarah's version, using fallback config parsing"
      return 1
    fi
  else
    log_warn "yq not available, using fallback config parsing"
    return 1
  fi
}

get_intent_min_threshold() {
  if load_config "${ROUTER_CONFIG}"; then
    yq eval '.thresholds.intent_min // 0.75' "${ROUTER_CONFIG}" 2>/dev/null || echo "0.75"
  else
    echo "0.75"
  fi
}

get_fallback_agent() {
  if load_config "${ROUTER_CONFIG}"; then
    yq eval '.thresholds.fallback_agent // "kim"' "${ROUTER_CONFIG}" 2>/dev/null || echo "kim"
  else
    echo "kim"
  fi
}

get_max_hops() {
  if load_config "${ROUTER_CONFIG}"; then
    yq eval '.max_hops // 3' "${ROUTER_CONFIG}" 2>/dev/null || echo "3"
  else
    echo "3"
  fi
}

# ============================================================================
# Intent Classification
# ============================================================================

classify_intent() {
  local text="$1"
  local current_agent="${2:-kim}"

  log_info "Classifying intent for text: $text"

  # Normalize text to lowercase for matching
  local text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

  local intent=""
  local confidence=0.0
  local target_agent=""

  # Code-related patterns (Andy)
  if echo "$text_lower" | grep -qE "(fix|bug|แก้|error|issue|debug)"; then
    intent="code.fix"
    confidence=0.85
    target_agent="andy"
  elif echo "$text_lower" | grep -qE "(implement|create|write|build|สร้าง|เขียน).*code|function|class"; then
    intent="code.implement"
    confidence=0.90
    target_agent="andy"
  elif echo "$text_lower" | grep -qE "(test|ทดสอบ|unit test|integration)"; then
    intent="code.test"
    confidence=0.85
    target_agent="andy"
  elif echo "$text_lower" | grep -qE "(refactor|optimize|improve|clean)"; then
    intent="code.refactor"
    confidence=0.80
    target_agent="andy"
  elif echo "$text_lower" | grep -qE "(review|check code|inspect)"; then
    intent="code.review"
    confidence=0.85
    target_agent="andy"
  elif echo "$text_lower" | grep -qE "(commit|push|git|pull request|pr)"; then
    intent="git.commit"
    confidence=0.90
    target_agent="andy"
  elif echo "$text_lower" | grep -qE "(deploy|release|publish|ship)"; then
    intent="code.deploy"
    confidence=0.80
    target_agent="andy"
  elif echo "$text_lower" | grep -qE "(build|compile|run build)"; then
    intent="build.run"
    confidence=0.80
    target_agent="andy"

  # Query-related patterns (Kim)
  elif echo "$text_lower" | grep -qE "(explain|describe|what is|tell me|อธิบาย)"; then
    intent="query.explain"
    confidence=0.85
    target_agent="kim"
  elif echo "$text_lower" | grep -qE "(translate|แปล|translation)"; then
    intent="query.translate"
    confidence=0.95
    target_agent="kim"
  elif echo "$text_lower" | grep -qE "(help|ช่วย|assist|support)"; then
    intent="query.help"
    confidence=0.85
    target_agent="kim"
  elif echo "$text_lower" | grep -qE "(clarify|unclear|ชี้แจง|confusing)"; then
    intent="query.clarify"
    confidence=0.80
    target_agent="kim"
  elif echo "$text_lower" | grep -qE "(documentation|docs|manual|เอกสาร)"; then
    intent="query.documentation"
    confidence=0.80
    target_agent="kim"
  elif echo "$text_lower" | grep -qE "(hello|hi|สวัสดี|chat|talk)"; then
    intent="conversation.chat"
    confidence=0.75
    target_agent="kim"

  else
    # Default to query.help with lower confidence
    intent="query.help"
    confidence=0.50
    target_agent=$(get_fallback_agent)
  fi

  # Output as JSON
  echo "{\"intent\":\"$intent\",\"confidence\":$confidence,\"target_agent\":\"$target_agent\"}"
}

# ============================================================================
# Circular Delegation Detection
# ============================================================================

check_circular_delegation() {
  local from_agent="$1"
  local to_agent="$2"

  # Check if we've already been to the target agent
  if echo "$DELEGATION_CHAIN" | grep -q "${to_agent}"; then
    log_error "Circular delegation detected: $DELEGATION_CHAIN -> $to_agent"
    emit_telemetry "router.circular" \
      "\"from_agent\":\"${from_agent}\",\"to_agent\":\"${to_agent}\",\"chain\":\"${DELEGATION_CHAIN}\""
    return 1
  fi

  # Check hop count
  HOP_COUNT=$((HOP_COUNT + 1))
  if [[ $HOP_COUNT -gt $MAX_HOPS ]]; then
    log_error "Max hops ($MAX_HOPS) exceeded"
    emit_telemetry "router.max_hops" \
      "\"from_agent\":\"${from_agent}\",\"to_agent\":\"${to_agent}\",\"hops\":${HOP_COUNT}"
    return 1
  fi

  # Update delegation chain
  if [[ -z "$DELEGATION_CHAIN" ]]; then
    DELEGATION_CHAIN="$from_agent"
  fi
  DELEGATION_CHAIN="${DELEGATION_CHAIN} -> ${to_agent}"

  return 0
}

# ============================================================================
# Routing Decision
# ============================================================================

make_routing_decision() {
  local intent="$1"
  local from_agent="$2"
  local confidence="$3"
  local text="$4"

  local intent_min=$(get_intent_min_threshold)
  local fallback=$(get_fallback_agent)

  # Get classification if not provided or if confidence is 0
  local classification
  local to_agent=""

  if [[ -z "$intent" ]] || [[ "$intent" == "null" ]] || [[ "$intent" == "" ]]; then
    # No intent provided, classify from text
    classification=$(classify_intent "$text" "$from_agent")
    intent=$(echo "$classification" | jq -r '.intent')
    confidence=$(echo "$classification" | jq -r '.confidence')
    to_agent=$(echo "$classification" | jq -r '.target_agent')
  else
    # Intent provided, determine target agent and use/boost confidence
    if echo "$intent" | grep -qE "^(code|git|file|build|test)\."; then
      to_agent="andy"
      # If no confidence provided, set high confidence for explicit intent
      if [[ -z "$confidence" ]] || [[ "$confidence" == "0" ]] || [[ "$confidence" == "0.0" ]]; then
        confidence="0.85"
      fi
    elif echo "$intent" | grep -qE "^(query|conversation|intent|translation|user)\."; then
      to_agent="kim"
      if [[ -z "$confidence" ]] || [[ "$confidence" == "0" ]] || [[ "$confidence" == "0.0" ]]; then
        confidence="0.85"
      fi
    else
      to_agent="$fallback"
      if [[ -z "$confidence" ]] || [[ "$confidence" == "0" ]] || [[ "$confidence" == "0.0" ]]; then
        confidence="0.50"
      fi
    fi
  fi

  # Check confidence threshold
  local below_threshold=0
  if (( $(echo "$confidence < $intent_min" | bc -l 2>/dev/null || echo "0") )); then
    below_threshold=1
  fi

  if [[ $below_threshold -eq 1 ]]; then
    log_warn "Confidence $confidence below threshold $intent_min, routing to fallback"
    to_agent="$fallback"
  fi

  # Determine reason
  local reason="pattern: $intent | confidence: $confidence"
  if [[ $below_threshold -eq 1 ]]; then
    reason="low confidence, fallback to $fallback"
  elif (( $(echo "$confidence >= 0.85" | bc -l 2>/dev/null || echo "0") )); then
    reason="pattern: $intent | high confidence"
  fi

  # Check for circular delegation
  if ! check_circular_delegation "$from_agent" "$to_agent"; then
    echo "{\"error\":\"circular_delegation\",\"from_agent\":\"$from_agent\",\"to_agent\":\"$to_agent\"}"
    return 1
  fi

  # Build decision output
  local decision=$(cat <<JSON
{
  "event": "router.decision",
  "ts": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "intent": "$intent",
  "from_agent": "$from_agent",
  "to_agent": "$to_agent",
  "confidence": $confidence,
  "reason": "$reason",
  "__source": "router_akr",
  "__normalized": true
}
JSON
)

  echo "$decision"

  # Emit telemetry
  if [[ $DRY_RUN -eq 0 ]]; then
    emit_telemetry "router.decision" \
      "\"intent\":\"${intent}\",\"from_agent\":\"${from_agent}\",\"to_agent\":\"${to_agent}\",\"confidence\":${confidence},\"reason\":\"${reason}\""
  fi

  return 0
}

# ============================================================================
# Main Commands
# ============================================================================

cmd_route() {
  local json_input="$1"

  emit_telemetry "router.start" "\"command\":\"route\""

  # Parse input JSON
  local agent=$(echo "$json_input" | jq -r '.agent // "kim"')
  local intent=$(echo "$json_input" | jq -r '.intent // ""')
  local text=$(echo "$json_input" | jq -r '.text // ""')
  local confidence=$(echo "$json_input" | jq -r '.confidence // 0.0')

  if [[ -z "$text" ]]; then
    log_error "Missing required field: text"
    emit_telemetry "router.error" "\"error\":\"missing_text\""
    return 1
  fi

  # Make routing decision
  local decision=$(make_routing_decision "$intent" "$agent" "$confidence" "$text")
  if [[ $? -ne 0 ]]; then
    emit_telemetry "router.error" "\"error\":\"routing_failed\""
    return 1
  fi

  # Output decision
  echo "$decision"

  emit_telemetry "router.end" "\"command\":\"route\",\"status\":\"success\""
  return 0
}

cmd_delegate() {
  local from_agent="$1"
  local to_agent="$2"
  local intent="$3"
  local text="$4"

  emit_telemetry "router.start" "\"command\":\"delegate\""

  # Check circular delegation
  if ! check_circular_delegation "$from_agent" "$to_agent"; then
    return 1
  fi

  # Emit delegation event
  emit_telemetry "router.delegate" \
    "\"from_agent\":\"${from_agent}\",\"to_agent\":\"${to_agent}\",\"intent\":\"${intent}\""

  # Build delegation output
  local delegation=$(cat <<JSON
{
  "event": "router.delegate",
  "ts": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "from_agent": "$from_agent",
  "to_agent": "$to_agent",
  "intent": "$intent",
  "text": "$text",
  "__source": "router_akr",
  "__normalized": true
}
JSON
)

  echo "$delegation"

  emit_telemetry "router.end" "\"command\":\"delegate\",\"status\":\"success\""
  return 0
}

cmd_selftest() {
  echo "Router AKR Self-Test"
  echo "===================="
  echo ""
  echo "Version: $VERSION"
  echo "Phase: $PHASE"
  echo "Work Order: $WORK_ORDER"
  echo ""

  # Check dependencies
  echo "Checking dependencies..."
  local deps_ok=1

  if ! command -v jq &>/dev/null; then
    echo "  ✗ jq not found"
    deps_ok=0
  else
    echo "  ✓ jq found"
  fi

  if ! command -v yq &>/dev/null; then
    echo "  ⚠ yq not found (optional, will use fallback)"
  else
    echo "  ✓ yq found"
  fi

  # Check config files
  echo ""
  echo "Checking configuration files..."

  if [[ -f "$ROUTER_CONFIG" ]]; then
    echo "  ✓ router_akr.yaml found"
  else
    echo "  ✗ router_akr.yaml not found"
    deps_ok=0
  fi

  if [[ -f "$ANDY_CONFIG" ]]; then
    echo "  ✓ andy.yaml found"
  else
    echo "  ✗ andy.yaml not found"
    deps_ok=0
  fi

  if [[ -f "$KIM_CONFIG" ]]; then
    echo "  ✓ kim.yaml found"
  else
    echo "  ✗ kim.yaml not found"
    deps_ok=0
  fi

  if [[ $deps_ok -eq 0 ]]; then
    echo ""
    echo "Self-test FAILED: Missing dependencies or config files"
    return 1
  fi

  echo ""
  echo "✓ Self-test PASSED"
  return 0
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
  # Parse global options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        ;;
      --verbose|-v)
        VERBOSE=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ $# -eq 0 ]]; then
    usage
  fi

  # Check if first argument is a known subcommand
  local subcommand="$1"
  case "$subcommand" in
    route|delegate|dry-run|selftest)
      shift
      ;;
    *)
      # Not a known subcommand, assume route if --dry-run was set
      if [[ $DRY_RUN -eq 1 ]]; then
        subcommand="route"
        # Don't shift, keep the arguments
      else
        log_error "Unknown subcommand: $subcommand"
        usage
      fi
      ;;
  esac

  # Load max hops from config
  MAX_HOPS=$(get_max_hops)

  case "$subcommand" in
    route)
      local json_input=""
      local file_path=""

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --json)
            json_input="$2"
            shift 2
            ;;
          --file)
            file_path="$2"
            shift 2
            ;;
          *)
            log_error "Unknown option: $1"
            usage
            ;;
        esac
      done

      if [[ -n "$file_path" ]]; then
        if [[ ! -f "$file_path" ]]; then
          log_error "File not found: $file_path"
          exit 1
        fi
        json_input=$(cat "$file_path")
      fi

      if [[ -z "$json_input" ]]; then
        log_error "Missing --json or --file option"
        usage
      fi

      cmd_route "$json_input"
      ;;

    delegate)
      local from_agent=""
      local to_agent=""
      local intent=""
      local text=""

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --from)
            from_agent="$2"
            shift 2
            ;;
          --to)
            to_agent="$2"
            shift 2
            ;;
          --intent)
            intent="$2"
            shift 2
            ;;
          --text)
            text="$2"
            shift 2
            ;;
          *)
            log_error "Unknown option: $1"
            usage
            ;;
        esac
      done

      if [[ -z "$from_agent" ]] || [[ -z "$to_agent" ]] || [[ -z "$intent" ]]; then
        log_error "Missing required options: --from, --to, --intent"
        usage
      fi

      cmd_delegate "$from_agent" "$to_agent" "$intent" "$text"
      ;;

    dry-run)
      DRY_RUN=1

      # Parse same options as route
      local json_input=""
      local file_path=""

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --json)
            json_input="$2"
            shift 2
            ;;
          --file)
            file_path="$2"
            shift 2
            ;;
          *)
            log_error "Unknown option: $1"
            usage
            ;;
        esac
      done

      if [[ -n "$file_path" ]]; then
        json_input=$(cat "$file_path")
      fi

      if [[ -z "$json_input" ]]; then
        log_error "Missing --json or --file option"
        usage
      fi

      cmd_route "$json_input"
      ;;

    selftest)
      cmd_selftest
      ;;

    *)
      log_error "Unknown subcommand: $subcommand"
      usage
      ;;
  esac
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]] || [[ "${ZSH_EVAL_CONTEXT:-}" == "toplevel" ]]; then
  main "$@"
fi
