#!/bin/bash
# Phase 20 — Integration Test
# Test CLS Web Bridge + Coordinator Load Test
# WO-ID: WO-251107-PHASE-20-CLS-WEB

set -euo pipefail

BASE="${BASE:-$HOME/02luka}"
CLS_URL="http://127.0.0.1:8778"

echo "=========================================="
echo "Phase 20 Integration Test"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_passed=0
test_failed=0

run_test() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Testing: $test_name ... "
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((test_passed++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((test_failed++))
        return 1
    fi
}

# 1. Health check
echo "1. CLS Web Bridge Health Check..."
echo "----------------------------------"

run_test "CLS Web Bridge health" \
    "curl -sf $CLS_URL/health > /dev/null"

# 2. Status endpoint
echo ""
echo "2. Status Endpoint..."
echo "---------------------"

run_test "Status endpoint" \
    "curl -sf $CLS_URL/status > /dev/null"

# 3. Metrics endpoint
echo ""
echo "3. Metrics Endpoint..."
echo "----------------------"

run_test "Metrics endpoint" \
    "curl -sf $CLS_URL/metrics > /dev/null"

# 4. Load test
echo ""
echo "4. Coordinator Load Test..."
echo "----------------------------"

if [ -x "$BASE/tools/coordinator_load_test.sh" ]; then
    run_test "Coordinator load test" \
        "bash $BASE/tools/coordinator_load_test.sh CONCURRENT=5 TOTAL=20 DELAY_MS=50"
else
    echo -e "${YELLOW}⚠ Load test script not found${NC}"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$test_passed${NC}"
echo -e "Failed: ${RED}$test_failed${NC}"
echo ""

if [ $test_failed -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed${NC}"
    exit 1
fi
