#!/usr/bin/env zsh
# Phase 1B Testing for Multi-Agent Coordination System
# Tests agent detection and gateway integration

set -uo pipefail

TEST_DIR=$(mktemp -d)
trap "rm -rf ${TEST_DIR}" EXIT

PASS=0
FAIL=0

test_result() {
    local name=$1
    local result=$2
    if [[ $result -eq 0 ]]; then
        echo "✅ PASS: $name"
        ((PASS++))
    else
        echo "❌ FAIL: $name"
        ((FAIL++))
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1B: Multi-Agent Coordination Testing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"

echo "📋 Agent Detection Tests"
echo "───────────────────────────────────────────────────────────────────"

# Test 1: Explicit AGENT_ID
AGENT=$(env -i AGENT_ID=CLS zsh -c "source '${SCRIPT_DIR}/agent_context.zsh' 2>/dev/null; echo \$AGENT_ID")
if [[ "$AGENT" == "CLS" ]]; then
    test_result "Explicit AGENT_ID=CLS" 0
else
    test_result "Explicit AGENT_ID=CLS (got: $AGENT)" 1
fi

# Test 2: Legacy GG_AGENT_ID
AGENT=$(env -i GG_AGENT_ID=CLS zsh -c "source '${SCRIPT_DIR}/agent_context.zsh' 2>/dev/null; echo \$AGENT_ID")
if [[ "$AGENT" == "CLS" ]]; then
    test_result "Legacy GG_AGENT_ID=CLS" 0
else
    test_result "Legacy GG_AGENT_ID=CLS (got: $AGENT)" 1
fi

# Test 3: Environment heuristic (TERM_PROGRAM=vscode)
AGENT=$(env -i TERM_PROGRAM=vscode zsh -c "source '${SCRIPT_DIR}/agent_context.zsh' 2>/dev/null; echo \$AGENT_ID")
if [[ "$AGENT" == "CLS" ]]; then
    test_result "Environment heuristic (TERM_PROGRAM=vscode)" 0
else
    test_result "Environment heuristic (TERM_PROGRAM=vscode) (got: $AGENT)" 1
fi

# Test 4: Unknown (no env vars)
AGENT=$(env -i zsh -c "source '${SCRIPT_DIR}/agent_context.zsh' 2>/dev/null; echo \$AGENT_ID")
if [[ "$AGENT" == "unknown" ]]; then
    test_result "Unknown (no env vars)" 0
else
    test_result "Unknown (no env vars) (got: $AGENT)" 1
fi

# Test 5: Validation (invalid agent)
AGENT=$(env -i AGENT_ID=INVALID_AGENT zsh -c "source '${SCRIPT_DIR}/agent_context.zsh' 2>/dev/null; echo \$AGENT_ID")
# Note: Current implementation doesn't validate, it just returns what's set
# This test checks current behavior (should return INVALID_AGENT)
# If validation is added later, this should return "unknown"
if [[ "$AGENT" == "INVALID_AGENT" ]]; then
    test_result "Invalid agent handling (current: returns as-is)" 0
else
    test_result "Invalid agent handling (got: $AGENT)" 1
fi

echo ""
echo "📋 Gateway Integration Tests"
echo "───────────────────────────────────────────────────────────────────"

# Test 6: save.sh with agent context
# Check if save.sh sources agent_context.zsh
if grep -q "agent_context.zsh" "${SCRIPT_DIR}/save.sh" 2>/dev/null; then
    test_result "save.sh sources agent_context.zsh" 0
else
    test_result "save.sh sources agent_context.zsh" 1
fi

# Test 7: save-now alias
# Check if save-now routes through save.sh
if grep -q "save.sh" "${SCRIPT_DIR}/git_safety_aliases.zsh" 2>/dev/null; then
    test_result "save-now alias routes through save.sh" 0
else
    test_result "save-now alias routes through save.sh" 1
fi

# Test 8: Backward compatibility
# Check if SAVE_SOURCE is still preserved
if grep -q "SAVE_SOURCE" "${SCRIPT_DIR}/save.sh" 2>/dev/null; then
    test_result "Backward compatibility (SAVE_SOURCE preserved)" 0
else
    test_result "Backward compatibility (SAVE_SOURCE preserved)" 1
fi

# Test 9: Telemetry schema enhancement
# Check if session_save.zsh has env and schema_version fields
if grep -q "schema_version" "${SCRIPT_DIR}/session_save.zsh" 2>/dev/null && \
   grep -q "\"env\"" "${SCRIPT_DIR}/session_save.zsh" 2>/dev/null; then
    test_result "Telemetry schema (env + schema_version fields)" 0
else
    test_result "Telemetry schema (env + schema_version fields)" 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Total:  $((PASS + FAIL))"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed. Review output above."
    exit 1
fi
