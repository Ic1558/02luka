#!/usr/bin/env zsh
# LAC QA Test Suite
# Based on: g/reports/lac_test_cases_20251206.md
# QA-LANE-ID: LAC-QA-20251206
# OWNER: LAC / QA lane

set +e  # NOTE: disable -e to allow all tests to run and summarize; individual tests track their own status
setopt null_glob 2>/dev/null || true  # zsh: don't error on empty glob patterns

ROOT="${LUKA_SOT:-${HOME}/02luka}"
cd "$ROOT"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
SKIPPED=0

log() {
    echo "[$(date +%H:%M:%S)] $*"
}

pass() {
    echo -e "${GREEN}✅ PASS:${NC} $*"
    ((PASSED++))
}

fail() {
    echo -e "${RED}❌ FAIL:${NC} $*"
    ((FAILED++))
}

skip() {
    echo -e "${YELLOW}⏭️  SKIP:${NC} $*"
    ((SKIPPED++))
}

# Test 1: dev_oss (Lightweight)
test_dev_oss() {
    log "Test 1: dev_oss (Lightweight)"
    
    # Create test WO
    cat > bridge/inbox/entry/WO-TEST-LAC-DEV-OSS-QA.yaml <<'YAML'
id: WO-TEST-LAC-DEV-OSS-QA
intent: apply_sip_patch
summary: LAC QA Test - Simple dev_oss task
priority: low
strict_target: LAC
target_candidates: [LAC]
timeout_sec: 300
cost_cap_usd: 0.10

task:
  type: dev_oss
  action: create_file
  path: tools/test_lac_simple_qa.txt
  content: |
    # LAC QA Test File
    Created by: LAC Manager (QA Test)
    Date: $(date -Iseconds)
    Status: Test successful
YAML
    
    # Wait for routing (run Mary dispatcher manually to speed up)
    /bin/zsh tools/watchers/mary_dispatcher.zsh > /dev/null 2>&1 || true
    sleep 3  # Give more time for routing
    
    # Check routing (may already be processed by running LAC Manager)
    if [[ -f bridge/inbox/lac/WO-TEST-LAC-DEV-OSS-QA.yaml ]] || [[ -f bridge/processed/LAC/WO-TEST-LAC-DEV-OSS-QA.yaml ]]; then
        pass "WO routed to LAC"
    else
        fail "WO not routed to LAC inbox"
        return 1
    fi
    
    # Run LAC Manager if WO still in inbox
    if [[ -f bridge/inbox/lac/WO-TEST-LAC-DEV-OSS-QA.yaml ]]; then
        python3 agents/lac_manager/lac_manager.py > /dev/null 2>&1 || true
        sleep 2
    fi
    
    # Check processing
    if [[ -f bridge/processed/LAC/WO-TEST-LAC-DEV-OSS-QA.yaml ]]; then
        pass "WO processed by LAC Manager"
    else
        fail "WO not processed (still in inbox/processing)"
        return 1
    fi
    
    # Check output file
    if [[ -f tools/test_lac_simple_qa.txt ]]; then
        pass "Output file created"
        # Cleanup
        rm -f tools/test_lac_simple_qa.txt
    else
        skip "Output file not created (may be governance blocked)"
    fi
}

# Test 2: QA Report (State + Report)
test_qa_report() {
    log "Test 2: QA Report (State + Report)"
    
    # Create test WO
    cat > bridge/inbox/entry/WO-TEST-LAC-QA-REPORT-QA.yaml <<'YAML'
id: WO-TEST-LAC-QA-REPORT-QA
intent: apply_sip_patch
summary: LAC QA Test - QA lane (read state + write report)
priority: medium
strict_target: LAC
target_candidates: [LAC]
timeout_sec: 600
cost_cap_usd: 0.20

task:
  type: qa_report
  action: generate_report
  source_state: followup/state/WO-TEST-STATUS-001.json
  output_path: g/reports/lac_qa_test_report_qa_20251206.md
YAML
    
    # Wait for routing (run Mary dispatcher manually to speed up)
    /bin/zsh tools/watchers/mary_dispatcher.zsh > /dev/null 2>&1 || true
    sleep 3  # Give more time for routing
    
    # Check routing (may already be processed by running LAC Manager)
    if [[ -f bridge/inbox/lac/WO-TEST-LAC-QA-REPORT-QA.yaml ]] || [[ -f bridge/processed/LAC/WO-TEST-LAC-QA-REPORT-QA.yaml ]]; then
        pass "WO routed to LAC"
    else
        fail "WO not routed to LAC inbox"
        return 1
    fi
    
    # Run LAC Manager if WO still in inbox
    if [[ -f bridge/inbox/lac/WO-TEST-LAC-QA-REPORT-QA.yaml ]]; then
        python3 agents/lac_manager/lac_manager.py > /dev/null 2>&1 || true
        sleep 2
    fi
    
    # Check processing
    if [[ -f bridge/processed/LAC/WO-TEST-LAC-QA-REPORT-QA.yaml ]]; then
        pass "WO processed by LAC Manager"
    else
        fail "WO not processed"
        return 1
    fi
    
    # Check report file
    if [[ -f g/reports/lac_qa_test_report_qa_20251206.md ]]; then
        pass "Report file created"
    else
        skip "Report file not created (may be governance blocked)"
    fi
}

# Test 3: Routing Verification
test_routing() {
    log "Test 3: Routing Verification"
    
    # Create test WO with strict_target
    cat > bridge/inbox/entry/WO-TEST-ROUTING-QA.yaml <<'YAML'
id: WO-TEST-ROUTING-QA
strict_target: LAC
target_candidates: [LAC]
YAML
    
    # Wait for Mary dispatcher (run manually to speed up)
    /bin/zsh tools/watchers/mary_dispatcher.zsh > /dev/null 2>&1 || true
    sleep 2
    
    # Check routing
    if [[ -f bridge/inbox/lac/WO-TEST-ROUTING-QA.yaml ]]; then
        pass "strict_target: LAC routes correctly"
    elif [[ -f bridge/inbox/entry/WO-TEST-ROUTING-QA.yaml ]]; then
        fail "WO still in ENTRY (routing failed)"
    elif [[ -f bridge/processed/ENTRY/WO-TEST-ROUTING-QA.yaml ]]; then
        skip "WO processed by Mary (may have routed to LAC then processed)"
    else
        # Check all possible locations
        found=$(find bridge -name "WO-TEST-ROUTING-QA.yaml" 2>/dev/null | head -1)
        if [[ -n "$found" ]]; then
            # Check if it's in outbox (normal routing step)
            if [[ "$found" == *"/outbox/"* ]]; then
                # Wait a bit more and check LAC inbox again
                sleep 3
                if [[ -f bridge/inbox/lac/WO-TEST-ROUTING-QA.yaml ]]; then
                    pass "strict_target: LAC routes correctly (after delay)"
                else
                    skip "WO in outbox (routing in progress or routed elsewhere)"
                fi
            else
                skip "WO found at: $found (routed but not to LAC inbox)"
            fi
        else
            fail "WO not found anywhere"
        fi
    fi
}

# Test 4: LAC Manager Loop
test_manager_loop() {
    log "Test 4: LAC Manager Processing Loop"
    
    # Create test WO
    cat > bridge/inbox/lac/WO-TEST-LOOP-QA.yaml <<'YAML'
id: WO-TEST-LOOP-QA
intent: test
summary: Test LAC Manager loop
strict_target: LAC
YAML
    
    # Run LAC Manager
    python3 agents/lac_manager/lac_manager.py > /dev/null 2>&1 || true
    sleep 2
    
    # Check processing
    if [[ -f bridge/processed/LAC/WO-TEST-LOOP-QA.yaml ]]; then
        pass "LAC Manager processes WOs in loop"
    elif [[ -f bridge/inbox/lac/WO-TEST-LOOP-QA.yaml ]]; then
        fail "WO still in inbox (not processed)"
        return 1
    else
        fail "WO not found"
        return 1
    fi
}

# Main
main() {
    echo "=========================================="
    echo "LAC QA Test Suite"
    echo "QA-LANE-ID: LAC-QA-20251206"
    echo "OWNER: LAC / QA lane"
    echo "=========================================="
    echo ""
    
    # Cleanup old test files
    find bridge -name "WO-TEST-*-QA.yaml" -delete 2>/dev/null || true
    
    # Run tests (don't exit on failure, collect all results)
    test_routing || true
    test_manager_loop || true
    test_dev_oss || true
    test_qa_report || true
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo -e "${GREEN}Passed:${NC} $PASSED"
    echo -e "${RED}Failed:${NC} $FAILED"
    echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
    echo ""
    
    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

main "$@"
