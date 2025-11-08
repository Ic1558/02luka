#!/usr/bin/env zsh
# Phase 15 – Router Core AKR Self-Test
# Validates Autonomous Knowledge Router functionality with telemetry
# Classification: Strategic Integration Patch (SIP)
# System: 02LUKA Cognitive Architecture
# Phase: 15 – Autonomous Knowledge Routing (AKR)
# Status: Active
# Maintainer: GG Core (02LUKA Automation)
# Version: v1.0.0
# Work Order: WO-251107-PHASE-15-AKR

set -uo pipefail
# Note: Don't use -e here because we want to continue on test failures

# Configuration
BASE="${LUKA_HOME:-$HOME/02luka}"
# Use absolute path to router
if [[ -f "${BASE}/tools/router_akr.zsh" ]]; then
    ROUTER="${BASE}/tools/router_akr.zsh"
elif [[ -f "$HOME/02luka/tools/router_akr.zsh" ]]; then
    ROUTER="$HOME/02luka/tools/router_akr.zsh"
    BASE="$HOME/02luka"
else
    ROUTER="./tools/router_akr.zsh"
fi
CONFIG="${BASE}/config/router_akr.yaml"
INTENT_MAP="${BASE}/config/nlp_command_map.yaml"
REPORT_DIR="${BASE}/g/reports/phase15"
REPORT_FILE="${REPORT_DIR}/router_akr_selftest.md"
TELEMETRY_SINK="${BASE}/g/telemetry_unified/unified.jsonl"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[selftest]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[selftest]${NC} ✓ $*" >&2
}

log_error() {
    echo -e "${RED}[selftest]${NC} ✗ $*" >&2
}

log_test() {
    echo -e "${YELLOW}[test $((TESTS_RUN+1))]${NC} $*" >&2
}

# Test assertion
assert() {
    local condition=$1
    local message=$2

    ((TESTS_RUN++))

    if eval "$condition" 2>/dev/null; then
        ((TESTS_PASSED++))
        log_success "$message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "$message"
        return 0  # Don't exit script on failure
    fi
}

# Setup test environment
setup_test_env() {
    log_info "Setting up test environment..."
    
    # Create report directory
    mkdir -p "$REPORT_DIR"
    
    # Ensure telemetry sink directory exists
    mkdir -p "$(dirname "$TELEMETRY_SINK")"
    
    log_success "Test environment ready"
}

# Test 1: Router configuration exists
test_config_exists() {
    log_test "Router configuration file exists"
    
    assert "[[ -f \"$CONFIG\" ]]" "Config file exists: $CONFIG"
}

# Test 2: Router tool exists and is executable
test_router_executable() {
    log_test "Router tool exists and is executable"
    
    assert "[[ -f \"$ROUTER\" ]]" "Router tool exists: $ROUTER"
    assert "[[ -x \"$ROUTER\" ]]" "Router tool is executable"
}

# Test 3: Intent map exists
test_intent_map_exists() {
    log_test "Intent map file exists"
    
    assert "[[ -f \"$INTENT_MAP\" ]]" "Intent map exists: $INTENT_MAP"
}

# Test 4: Router routes coding queries to Andy
test_code_routing_to_andy() {
    log_test "Router routes coding queries to Andy"
    
    local query="write a function to parse JSON"
    local output
    output=$(bash "$ROUTER" "$query" 2>&1 || echo "")
    
    local routed_to=$(echo "$output" | grep "^ROUTE_TO:" | cut -d: -f2 | tr -d ' ')
    
    assert "[[ \"$routed_to\" == \"andy\" ]]" "Coding query routed to Andy (got: $routed_to)"
}

# Test 5: Router routes explanation queries to Kim
test_explain_routing_to_kim() {
    log_test "Router routes explanation queries to Kim"
    
    local query="explain how vector search works"
    local output
    output=$(bash "$ROUTER" "$query" 2>&1 || echo "")
    
    local routed_to=$(echo "$output" | grep "^ROUTE_TO:" | cut -d: -f2 | tr -d ' ')
    
    assert "[[ \"$routed_to\" == \"kim\" ]]" "Explanation query routed to Kim (got: $routed_to)"
}

# Test 6: Router emits telemetry
test_telemetry_emission() {
    log_test "Router emits telemetry events"
    
    # Get initial telemetry count
    local initial_count=0
    if [[ -f "$TELEMETRY_SINK" ]]; then
        initial_count=$(wc -l < "$TELEMETRY_SINK" | tr -d ' ')
    fi
    
    # Run router
    bash "$ROUTER" "test query for telemetry" >/dev/null 2>&1 || true
    
    # Check if telemetry was added
    local final_count=0
    if [[ -f "$TELEMETRY_SINK" ]]; then
        final_count=$(wc -l < "$TELEMETRY_SINK" | tr -d ' ')
    fi
    
    assert "[[ $final_count -gt $initial_count ]]" "Telemetry events emitted (initial: $initial_count, final: $final_count)"
}

# Test 7: Router returns valid output format
test_output_format() {
    log_test "Router returns valid output format"
    
    local query="test query"
    local output
    output=$(bash "$ROUTER" "$query" 2>&1 || echo "")
    
    local has_route_to=$(echo "$output" | grep -q "^ROUTE_TO:" && echo "yes" || echo "no")
    local has_classification=$(echo "$output" | grep -q "^CLASSIFICATION:" && echo "yes" || echo "no")
    
    assert "[[ \"$has_route_to\" == \"yes\" && \"$has_classification\" == \"yes\" ]]" "Output format is valid"
}

# Test 8: Router handles empty query gracefully
test_empty_query_handling() {
    log_test "Router handles empty query gracefully"
    
    local output
    output=$(bash "$ROUTER" "" 2>&1 || echo "EXIT_CODE:$?")
    
    local has_usage=$(echo "$output" | grep -qi "usage" && echo "yes" || echo "no")
    local exit_code=$(echo "$output" | grep "EXIT_CODE:" | cut -d: -f2 || echo "0")
    
    assert "[[ \"$has_usage\" == \"yes\" || \"$exit_code\" != \"0\" ]]" "Empty query handled gracefully"
}

# Generate report
generate_report() {
    log_info "Generating test report..."
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local pass_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        pass_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    cat > "$REPORT_FILE" <<EOF
# Router Core AKR Self-Test Report

**Timestamp:** $timestamp
**Tests Run:** $TESTS_RUN
**Tests Passed:** $TESTS_PASSED
**Tests Failed:** $TESTS_FAILED
**Pass Rate:** ${pass_rate}%

## Test Results

EOF

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All tests passed!" >> "$REPORT_FILE"
    else
        echo "❌ Some tests failed. See output above for details." >> "$REPORT_FILE"
    fi
    
    log_success "Report written to: $REPORT_FILE"
}

# Main test execution
main() {
    log_info "Starting Router Core AKR self-test..."
    log_info "Router: $ROUTER"
    log_info "Config: $CONFIG"
    log_info ""
    
    setup_test_env
    
    # Run tests
    test_config_exists
    test_router_executable
    test_intent_map_exists
    test_code_routing_to_andy
    test_explain_routing_to_kim
    test_telemetry_emission
    test_output_format
    test_empty_query_handling
    
    # Generate report
    generate_report
    
    # Print summary
    log_info ""
    log_info "=== Test Summary ==="
    log_info "Tests Run: $TESTS_RUN"
    log_info "Tests Passed: $TESTS_PASSED"
    log_info "Tests Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

main "$@"
