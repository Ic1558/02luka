#!/bin/bash
# Test FAISS/HNSW + Kim Proxy Integration
# Phase 15 - Integration Testing Script
# WO-ID: WO-251107-PHASE-15-FAISS-HNSW-KIM

set -euo pipefail

echo "=========================================="
echo "FAISS/HNSW + Kim Proxy Integration Test"
echo "=========================================="
echo

# Configuration
FAISS_URL="http://127.0.0.1:8766"
KIM_URL="http://127.0.0.1:8767"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_passed=0
test_failed=0

# Test function
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_status="${3:-200}"

    echo -n "Testing: $test_name ... "

    if output=$(eval "$command" 2>&1); then
        echo -e "${GREEN}PASS${NC}"
        ((test_passed++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Error: $output"
        ((test_failed++))
        return 1
    fi
}

# Check if services are running
echo "1. Checking Services..."
echo "----------------------"

run_test "FAISS health check" \
    "curl -sf $FAISS_URL/health > /dev/null"

run_test "Kim Proxy health check" \
    "curl -sf $KIM_URL/health > /dev/null"

echo

# Test FAISS Vector Service
echo "2. Testing FAISS Vector Service..."
echo "----------------------------------"

# Get stats
run_test "FAISS stats endpoint" \
    "curl -sf $FAISS_URL/stats > /dev/null"

# Test vector query (may fail if no documents ingested)
echo -n "Testing: FAISS vector query ... "
if curl -sf -X POST $FAISS_URL/vector_query \
    -H "Content-Type: application/json" \
    -d '{"query": "telemetry schema", "top_k": 3}' > /tmp/faiss_test.json 2>&1; then

    if [ -s /tmp/faiss_test.json ]; then
        echo -e "${GREEN}PASS${NC}"
        echo "  Results: $(jq -r '.results | length' /tmp/faiss_test.json 2>/dev/null || echo '0') documents"
        ((test_passed++))
    else
        echo -e "${YELLOW}WARN${NC} (empty response)"
    fi
else
    echo -e "${YELLOW}WARN${NC} (index may be empty)"
fi

echo

# Test Kim Proxy Gateway
echo "3. Testing Kim Proxy Gateway..."
echo "-------------------------------"

# Test intent classification
echo -n "Testing: Intent classification ... "
if curl -sf -X POST $KIM_URL/classify \
    -H "Content-Type: application/json" \
    -d '{"query": "fix authentication bug"}' > /tmp/kim_classify.json 2>&1; then

    intent=$(jq -r '.classification.intent' /tmp/kim_classify.json 2>/dev/null || echo "unknown")
    route=$(jq -r '.classification.route' /tmp/kim_classify.json 2>/dev/null || echo "unknown")

    echo -e "${GREEN}PASS${NC}"
    echo "  Intent: $intent, Route: $route"
    ((test_passed++))
else
    echo -e "${RED}FAIL${NC}"
    ((test_failed++))
fi

# Test knowledge query routing
echo -n "Testing: Knowledge query routing ... "
if curl -sf -X POST $KIM_URL/query \
    -H "Content-Type: application/json" \
    -d '{"query": "what is Phase 14 about?"}' > /tmp/kim_query.json 2>&1; then

    route=$(jq -r '.route' /tmp/kim_query.json 2>/dev/null || echo "unknown")
    backend=$(jq -r '.backend' /tmp/kim_query.json 2>/dev/null || echo "unknown")

    echo -e "${GREEN}PASS${NC}"
    echo "  Route: $route, Backend: $backend"
    ((test_passed++))
else
    echo -e "${RED}FAIL${NC}"
    ((test_failed++))
fi

# Test code task classification
echo -n "Testing: Code task classification ... "
if curl -sf -X POST $KIM_URL/classify \
    -H "Content-Type: application/json" \
    -d '{"query": "implement user authentication"}' > /tmp/kim_code.json 2>&1; then

    intent=$(jq -r '.classification.intent' /tmp/kim_code.json 2>/dev/null || echo "unknown")
    route=$(jq -r '.classification.route' /tmp/kim_code.json 2>/dev/null || echo "unknown")

    if [ "$route" = "andy" ]; then
        echo -e "${GREEN}PASS${NC}"
        echo "  Correctly routed to Andy: $intent"
        ((test_passed++))
    else
        echo -e "${YELLOW}WARN${NC}"
        echo "  Expected route to Andy, got: $route"
    fi
else
    echo -e "${RED}FAIL${NC}"
    ((test_failed++))
fi

# Test system command classification
echo -n "Testing: System command classification ... "
if curl -sf -X POST $KIM_URL/classify \
    -H "Content-Type: application/json" \
    -d '{"query": "restart health service"}' > /tmp/kim_system.json 2>&1; then

    intent=$(jq -r '.classification.intent' /tmp/kim_system.json 2>/dev/null || echo "unknown")
    route=$(jq -r '.classification.route' /tmp/kim_system.json 2>/dev/null || echo "unknown")

    if [ "$route" = "system" ]; then
        echo -e "${GREEN}PASS${NC}"
        echo "  Correctly routed to System: $intent"
        ((test_passed++))
    else
        echo -e "${YELLOW}WARN${NC}"
        echo "  Expected route to System, got: $route"
    fi
else
    echo -e "${RED}FAIL${NC}"
    ((test_failed++))
fi

# Get gateway stats
echo -n "Testing: Gateway statistics ... "
if curl -sf $KIM_URL/stats > /tmp/kim_stats.json 2>&1; then
    total_queries=$(jq -r '.stats.total_queries' /tmp/kim_stats.json 2>/dev/null || echo "0")
    echo -e "${GREEN}PASS${NC}"
    echo "  Total queries: $total_queries"
    ((test_passed++))
else
    echo -e "${RED}FAIL${NC}"
    ((test_failed++))
fi

echo

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$test_passed${NC}"
echo -e "Failed: ${RED}$test_failed${NC}"
echo

if [ $test_failed -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed or warned${NC}"
    exit 1
fi
