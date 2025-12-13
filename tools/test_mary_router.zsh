#!/usr/bin/env zsh
# test_mary_router.zsh
# Test suite for Mary Router Phase 1 - Operational Sanity Check
# Verifies all 12 zone/source/operation combinations

set -uo pipefail

LUKA_ROOT="${LUKA_ROOT:-$HOME/02luka}"
MARY_SCRIPT="${LUKA_ROOT}/tools/mary_dispatch.py"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_case() {
  local test_num=$1
  local source=$2
  local zone_type=$3
  local op=$4
  local expected_lane=$5
  local expected_agent=$6
  local test_path=""
  
  # Set test path based on zone type
  case "$zone_type" in
    "OPEN")
      test_path="g/reports/test_mary_${test_num}.md"
      ;;
    "LOCKED")
      test_path="core/test_mary_${test_num}.md"
      ;;
    *)
      echo "❌ Unknown zone type: $zone_type"
      return 1
      ;;
  esac
  
  echo -n "Test $test_num: $zone_type / $source / $op → "
  
  # Run Mary Router and capture JSON output
  local output
  output=$(python3 "$MARY_SCRIPT" --source "$source" --path "$test_path" --op "$op" --json 2>&1)
  
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}FAILED${NC} (execution error)"
    echo "  Error: $output"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("Test $test_num")
    return 1
  fi
  
  # Parse JSON output
  local actual_lane actual_agent
  actual_lane=$(echo "$output" | python3 -c "import sys, json; print(json.load(sys.stdin)['lane'])" 2>/dev/null || echo "")
  actual_agent=$(echo "$output" | python3 -c "import sys, json; print(json.load(sys.stdin)['agent'])" 2>/dev/null || echo "")
  
  if [[ -z "$actual_lane" ]] || [[ -z "$actual_agent" ]]; then
    echo -e "${RED}FAILED${NC} (JSON parse error)"
    echo "  Output: $output"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("Test $test_num")
    return 1
  fi
  
  # Verify expectations
  local lane_ok=false agent_ok=false
  
  if [[ "$actual_lane" == "$expected_lane" ]]; then
    lane_ok=true
  fi
  
  if [[ "$actual_agent" == "$expected_agent" ]]; then
    agent_ok=true
  fi
  
  if [[ "$lane_ok" == true ]] && [[ "$agent_ok" == true ]]; then
    echo -e "${GREEN}PASS${NC}"
    echo "  Lane: $actual_lane, Agent: $actual_agent"
    ((TESTS_PASSED++))
    return 0
  else
    echo -e "${RED}FAILED${NC}"
    if [[ "$lane_ok" == false ]]; then
      echo "  Expected lane: $expected_lane, Got: $actual_lane"
    fi
    if [[ "$agent_ok" == false ]]; then
      echo "  Expected agent: $expected_agent, Got: $actual_agent"
    fi
    ((TESTS_FAILED++))
    FAILED_TESTS+=("Test $test_num")
    return 1
  fi
}

echo "🧪 Mary Router Phase 1 - Test Suite"
echo "===================================="
echo ""

# Test Cases (12 total)
# Open Zone / Interactive
test_case 1 "interactive" "OPEN" "write" "FAST" "GMX_CODEX"
test_case 2 "interactive" "OPEN" "read" "FAST" "GMX_CODEX"
test_case 3 "interactive" "OPEN" "delete" "FAST" "GMX_CODEX"

# Open Zone / Background
test_case 4 "background" "OPEN" "write" "STRICT" "CLC"
test_case 5 "background" "OPEN" "read" "STRICT" "CLC"
test_case 6 "background" "OPEN" "delete" "STRICT" "CLC"

# Locked Zone / Interactive
test_case 7 "interactive" "LOCKED" "write" "WARN" "CLC_OR_OVERRIDE"
test_case 8 "interactive" "LOCKED" "read" "FAST" "GMX_CODEX"
test_case 9 "interactive" "LOCKED" "delete" "WARN" "CLC_OR_OVERRIDE"

# Locked Zone / Background
test_case 10 "background" "LOCKED" "write" "STRICT" "CLC"
test_case 11 "background" "LOCKED" "read" "STRICT" "CLC"
test_case 12 "background" "LOCKED" "delete" "STRICT" "CLC"

echo ""
echo "===================================="
echo "📊 Test Results:"
echo "   Passed: $TESTS_PASSED"
echo "   Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✅ All tests passed! Mary Router is 100% reliable.${NC}"
  exit 0
else
  echo -e "${RED}❌ $TESTS_FAILED test(s) failed:${NC}"
  for test in "${FAILED_TESTS[@]}"; do
    echo "   - $test"
  done
  exit 1
fi
