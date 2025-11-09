#!/usr/bin/env bash
#
# Global Validation Script
# Smart, extensible validation for the 02LUKA system
#
# ⚠️  STATUS: IN DEVELOPMENT - NOT READY FOR PRODUCTION USE
# This script is experimental and may have issues. Use tools/ci/validate.sh instead.
#
# Features:
# - Configuration-driven validation rules
# - Parallel execution for speed
# - Smart caching for performance
# - Extensible hook system
# - Comprehensive metrics
# - Auto-fix capabilities
#
# Usage:
#   global_validate.sh [OPTIONS]
#
# Options:
#   --help, -h          Show this help
#   --config FILE       Use specific config file
#   --category CAT      Run only validators in category (critical|important|optional)
#   --validator NAME    Run specific validator
#   --fail-fast         Stop on first failure
#   --no-cache          Disable result caching
#   --auto-fix          Auto-fix fixable issues
#   --report FORMAT     Output format (compact|detailed|json)
#   --ci                CI mode (applies CI-specific settings)
#   --quiet             Minimal output
#   --verbose           Verbose output
#
# Examples:
#   # Run all validators
#   ./tools/global_validate.sh
#
#   # Run only critical validators
#   ./tools/global_validate.sh --category critical
#
#   # Run specific validator
#   ./tools/global_validate.sh --validator git_repository
#
#   # CI mode with fail-fast
#   ./tools/global_validate.sh --ci --fail-fast
#
#   # Auto-fix issues
#   ./tools/global_validate.sh --auto-fix
#

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Development Status Warning
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Show warning unless explicitly disabled
if [[ "${SKIP_DEV_WARNING:-0}" != "1" ]]; then
  echo "⚠️  WARNING: This script is IN DEVELOPMENT and NOT READY FOR PRODUCTION USE" >&2
  echo "   Status: Experimental (PR #244)" >&2
  echo "   Known Issues: Output display problems, associative array handling" >&2
  echo "   Recommendation: Use tools/ci/validate.sh for production validation" >&2
  echo "   To suppress this warning: SKIP_DEV_WARNING=1 $0" >&2
  echo "" >&2
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration & Defaults
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE=".github/validation.config.yml"
CATEGORY="all"
VALIDATOR=""
FAIL_FAST=false
NO_CACHE=false
AUTO_FIX=false
REPORT_FORMAT="detailed"
CI_MODE=false
QUIET=false
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
  [[ "$QUIET" == "true" ]] && return 0
  local color=$1; shift
  echo -e "${color}$@${NC}" >&2
}

verbose() {
  [[ "$VERBOSE" != "true" ]] && return 0
  log "$GRAY" "$@"
}

show_help() {
  sed -n '2,/^$/p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Argument Parsing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

while (( $# )); do
  case "$1" in
    --help|-h)
      show_help
      ;;
    --config)
      CONFIG_FILE="$2"
      shift
      ;;
    --category)
      CATEGORY="$2"
      shift
      ;;
    --validator)
      VALIDATOR="$2"
      shift
      ;;
    --fail-fast)
      FAIL_FAST=true
      ;;
    --no-cache)
      NO_CACHE=true
      ;;
    --auto-fix)
      AUTO_FIX=true
      ;;
    --report)
      REPORT_FORMAT="$2"
      shift
      ;;
    --ci)
      CI_MODE=true
      ;;
    --quiet|-q)
      QUIET=true
      ;;
    --verbose|-v)
      VERBOSE=true
      ;;
    *)
      log "$RED" "Unknown argument: $1"
      exit 1
      ;;
  esac
  shift
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Declare global arrays and counters first
declare -A VALIDATOR_RESULTS
declare -A VALIDATOR_DURATIONS
declare -A CACHE_STORE

TOTAL_VALIDATORS=0
PASSED_VALIDATORS=0
FAILED_VALIDATORS=0
WARNED_VALIDATORS=0

# Source smart library
if [[ -f "$SCRIPT_DIR/lib/validation_smart.sh" ]]; then
  source "$SCRIPT_DIR/lib/validation_smart.sh"
else
  log "$RED" "❌ Smart library not found: $SCRIPT_DIR/lib/validation_smart.sh"
  exit 1
fi

# Load configuration
verbose "Loading configuration from: $CONFIG_FILE"
load_validation_config "$CONFIG_FILE" || log "$YELLOW" "⚠️  Using default configuration"

# CI mode overrides
if [[ "$CI_MODE" == "true" ]]; then
  verbose "CI mode enabled - applying overrides"
  FAIL_FAST=$(get_validation_config "ci_mode.overrides.fail_fast" "true")
  QUIET=true
fi

# Respect environment variables
if [[ "${CI_QUIET:-}" == "1" ]]; then
  QUIET=true
fi

# Initialize cache
if [[ "$NO_CACHE" != "true" ]]; then
  cache_init
  verbose "Cache initialized"
fi

# Initialize metrics
init_validation_metrics
verbose "Metrics initialized"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Banner
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [[ "$QUIET" != "true" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🧪 Global Validation System"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Pre-validation Hook
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_validation_hook "pre_validate"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Determine Validators to Run
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

declare -a VALIDATORS_TO_RUN

if [[ -n "$VALIDATOR" ]]; then
  # Run specific validator
  VALIDATORS_TO_RUN=("$VALIDATOR")
  verbose "Running single validator: $VALIDATOR"
elif [[ "$CATEGORY" == "all" ]]; then
  # Run all validators
  CRITICAL=($(get_validation_config "validators.critical" "[]" | jq -r '.[]' 2>/dev/null || echo ""))
  IMPORTANT=($(get_validation_config "validators.important" "[]" | jq -r '.[]' 2>/dev/null || echo ""))
  OPTIONAL=($(get_validation_config "validators.optional" "[]" | jq -r '.[]' 2>/dev/null || echo ""))

  VALIDATORS_TO_RUN=("${CRITICAL[@]}" "${IMPORTANT[@]}" "${OPTIONAL[@]}")
  verbose "Running all validators (${#VALIDATORS_TO_RUN[@]} total)"
else
  # Run specific category
  VALIDATORS_TO_RUN=($(get_validation_config "validators.${CATEGORY}" "[]" | jq -r '.[]' 2>/dev/null || echo ""))
  verbose "Running $CATEGORY validators (${#VALIDATORS_TO_RUN[@]} total)"
fi

if (( ${#VALIDATORS_TO_RUN[@]} == 0 )); then
  log "$RED" "❌ No validators to run"
  exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run Validators
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HAS_FAILURES=false

for validator in "${VALIDATORS_TO_RUN[@]}"; do
  [[ -z "$validator" ]] && continue

  if [[ "$QUIET" != "true" ]]; then
    printf "  %-30s " "$validator"
  fi

  run_validation_hook "on_validator_start" "$validator"

  start=$(date +%s%3N)

  set +e
  output=$(run_validator "$validator" 2>&1)
  result=$?
  set -e

  # Show verbose output
  if [[ "$VERBOSE" == "true" && -n "$output" ]]; then
    echo "$output" | while read -r line; do
      verbose "    $line"
    done
  fi

  end=$(date +%s%3N)
  duration=$(( (end - start) ))

  # Get result (with fallback if not set)
  status="${VALIDATOR_RESULTS[$validator]:-SKIP}"
  status="${status%%|*}"
  message="${VALIDATOR_RESULTS[$validator]:-}"
  message="${message#*|}"

  # Display result
  if [[ "$QUIET" != "true" ]]; then
    case "$status" in
      PASS)
        echo -e "${GREEN}✅ PASS${NC} ${GRAY}(${duration}ms)${NC}"
        ;;
      FAIL)
        echo -e "${RED}❌ FAIL${NC} ${GRAY}(${duration}ms)${NC}"
        echo -e "    ${RED}${message}${NC}"
        HAS_FAILURES=true
        ;;
      WARN)
        echo -e "${YELLOW}⚠️  WARN${NC} ${GRAY}(${duration}ms)${NC}"
        [[ "$VERBOSE" == "true" ]] && echo -e "    ${YELLOW}${message}${NC}"
        ;;
      SKIP)
        echo -e "${GRAY}⊝  SKIP${NC} ${GRAY}(${duration}ms)${NC}"
        ;;
    esac
  fi

  # Record metric
  record_validator_metric "$validator" "$status" "$duration" "$message"

  run_validation_hook "on_validator_complete" "$validator" "$status" "$duration"

  # Fail fast
  if [[ "$FAIL_FAST" == "true" ]] && [[ "$status" == "FAIL" ]]; then
    log "$RED" ""
    log "$RED" "❌ Stopping due to failure (--fail-fast)"
    break
  fi
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Finalize
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

finalize_validation_metrics

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Summary
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [[ "$QUIET" != "true" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "SUMMARY"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo -e "  Total:    $TOTAL_VALIDATORS"
  echo -e "  ${GREEN}Passed:   $PASSED_VALIDATORS${NC}"

  if (( FAILED_VALIDATORS > 0 )); then
    echo -e "  ${RED}Failed:   $FAILED_VALIDATORS${NC}"
  fi

  if (( WARNED_VALIDATORS > 0 )); then
    echo -e "  ${YELLOW}Warned:   $WARNED_VALIDATORS${NC}"
  fi

  echo ""

  if [[ -n "${VALIDATION_METRICS:-}" ]]; then
    echo -e "${GRAY}Metrics saved to: $VALIDATION_METRICS${NC}"
  fi

  echo ""
fi

# Post-validation hook
if [[ "$HAS_FAILURES" == "true" ]]; then
  run_validation_hook "on_failure" "$FAILED_VALIDATORS"
else
  run_validation_hook "on_success" "$PASSED_VALIDATORS"
fi

run_validation_hook "post_validate" "$TOTAL_VALIDATORS" "$PASSED_VALIDATORS" "$FAILED_VALIDATORS"

# Exit code
if [[ "$HAS_FAILURES" == "true" ]]; then
  [[ "$QUIET" != "true" ]] && log "$RED" "❌ Validation failed"
  exit 1
else
  [[ "$QUIET" != "true" ]] && log "$GREEN" "✅ Validation passed"
  exit 0
fi
