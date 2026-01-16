#!/usr/bin/env zsh
# feature_dev_validate.zsh — Mandatory Validation Gate for Feature Development
#
# Purpose: Force full validation/verification/scoring before claiming completion
# This prevents "missing jigsaw pieces" and ensures production-readiness check
#
# Usage: zsh tools/feature_dev_validate.zsh <feature-slug>
# Example: zsh tools/feature_dev_validate.zsh catalog_gate_system

set -uo pipefail
# Don't use set -e, we want to catch all test results even if some fail

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
FEATURE_SLUG="${1:-}"

if [[ -z "$FEATURE_SLUG" ]]; then
    cat << 'EOF' >&2
Usage: zsh tools/feature_dev_validate.zsh <feature-slug>

This script enforces mandatory validation/verification/scoring:
1. Run all relevant tests
2. Calculate weighted score
3. Check quality gates
4. Generate validation report
5. Block completion if score < 90

Example:
    zsh tools/feature_dev_validate.zsh catalog_gate_system
EOF
    exit 1
fi

REPORT_DIR="$LUKA_BASE/g/reports/feature-dev/$FEATURE_SLUG"
VALIDATION_REPORT="$REPORT_DIR/$(date +%Y%m%d)_VALIDATION_SCORE.md"

mkdir -p "$REPORT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

QUALITY_GATE=90
total_score=0
total_weight=0
test_results=()
test_status=""

echo "${CYAN}🔍 Feature Validation: $FEATURE_SLUG${NC}"
echo "═══════════════════════════════════════════════════════════"

# Test 1: Catalog Integrity
echo ""
echo "${CYAN}Test 1: Catalog Integrity${NC}"
if python3 "$LUKA_BASE/tests/test_catalog_integrity.py" 2>&1; then
    score=10
    weight=30
    test_status="✅ PASSED"
    test_results+=("Catalog Integrity|$score|$weight|$test_status")
    total_score=$((total_score + score * weight))
    total_weight=$((total_weight + weight))
else
    score=0
    weight=30
    test_status="❌ FAILED"
    test_results+=("Catalog Integrity|$score|$weight|$test_status")
    total_weight=$((total_weight + weight))
fi

# Test 2: No Direct Tool Calls
echo ""
echo "${CYAN}Test 2: No Direct Tool Calls${NC}"
test2_output=$(zsh "$LUKA_BASE/tests/test_no_direct_tool_calls.sh" 2>&1)
test2_result=$(echo "$test2_output" | tail -1)
echo "$test2_result"
if echo "$test2_result" | /usr/bin/grep -q "✅"; then
    score=10
    weight=25
    test_status="✅ PASSED"
    test_results+=("No Direct Calls|$score|$weight|$test_status")
    total_score=$((total_score + score * weight))
    total_weight=$((total_weight + weight))
else
    score=0
    weight=25
    test_status="❌ FAILED"
    test_results+=("No Direct Calls|$score|$weight|$test_status")
    total_weight=$((total_weight + weight))
fi

# Test 3: Catalog Lookup
echo ""
echo "${CYAN}Test 3: Catalog Lookup${NC}"
lookup_output=$(zsh "$LUKA_BASE/tools/catalog_lookup.zsh" code-review 2>&1)
echo "$lookup_output" | head -3
# Strip color codes and check
lookup_clean=$(echo "$lookup_output" | sed 's/\x1b\[[0-9;]*m//g')
if echo "$lookup_clean" | /usr/bin/grep -q "Command:"; then
    score=10
    weight=20
    test_status="✅ PASSED"
    test_results+=("Catalog Lookup|$score|$weight|$test_status")
    total_score=$((total_score + score * weight))
    total_weight=$((total_weight + weight))
else
    score=0
    weight=20
    test_status="❌ FAILED"
    test_results+=("Catalog Lookup|$score|$weight|$test_status")
    total_weight=$((total_weight + weight))
fi

# Test 4: run_tool.zsh Wrapper
echo ""
echo "${CYAN}Test 4: run_tool.zsh Wrapper${NC}"
wrapper_output=$(zsh "$LUKA_BASE/tools/run_tool.zsh" nonexistent-tool 2>&1 || true)
echo "$wrapper_output" | head -3
# Strip color codes and check
wrapper_clean=$(echo "$wrapper_output" | sed 's/\x1b\[[0-9;]*m//g')
if echo "$wrapper_clean" | /usr/bin/grep -q "not found"; then
    score=9
    weight=25
    test_status="✅ PASSED"
    test_results+=("run_tool.zsh|$score|$weight|$test_status")
    total_score=$((total_score + score * weight))
    total_weight=$((total_weight + weight))
else
    score=0
    weight=25
    test_status="❌ FAILED"
    test_results+=("run_tool.zsh|$score|$weight|$test_status")
    total_weight=$((total_weight + weight))
fi

# Calculate weighted score (percentage)
if [[ $total_weight -gt 0 ]]; then
    # total_score is sum of (score * weight) for each test
    # final_score = (total_score / total_weight) * 100
    # But we want percentage, so: (total_score / (total_weight * 10)) * 100
    # Since each score is out of 10, max possible = total_weight * 10
    max_possible=$((total_weight * 10))
    final_score=$((total_score * 100 / max_possible))
else
    final_score=0
fi

# Generate report
cat > "$VALIDATION_REPORT" << EOF
# Feature Validation Score: $FEATURE_SLUG

**Date:** $(date +%Y-%m-%d)  
**Feature Slug:** $FEATURE_SLUG  
**Quality Gate:** $QUALITY_GATE%  
**Final Score:** **$final_score/100**

---

## Test Results

| Test | Score | Weight | Status |
|------|-------|--------|--------|
EOF

for result in "${test_results[@]}"; do
    IFS='|' read -r test_name score weight test_status <<< "$result"
    echo "| $test_name | $score/10 | ${weight}% | $test_status |" >> "$VALIDATION_REPORT"
done

cat >> "$VALIDATION_REPORT" << EOF

---

## Score Calculation

- **Total Weighted Score:** $total_score / $total_weight
- **Final Score:** **$final_score/100**
- **Quality Gate:** $QUALITY_GATE%
- **Gate Status:** $([ $final_score -ge $QUALITY_GATE ] && echo "✅ PASSED" || echo "❌ FAILED")

---

## Production Readiness

**Status:** $([ $final_score -ge $QUALITY_GATE ] && echo "✅ PRODUCTION READY" || echo "❌ NOT READY")

$([ $final_score -ge $QUALITY_GATE ] && echo "All quality gates passed. Code is production-ready." || echo "Quality gate failed. Fix issues before claiming completion.")

---

**Generated by:** feature_dev_validate.zsh  
**Timestamp:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# Display summary
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "${CYAN}📊 Validation Summary${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Final Score: ${CYAN}$final_score/100${NC}"
echo "Quality Gate: $QUALITY_GATE%"
echo ""

if [[ $final_score -ge $QUALITY_GATE ]]; then
    echo "${GREEN}✅ PRODUCTION READY${NC}"
    echo "   All quality gates passed."
    echo ""
    echo "Report: $VALIDATION_REPORT"
    exit 0
else
    echo "${RED}❌ NOT PRODUCTION READY${NC}"
    echo "   Quality gate failed ($final_score% < $QUALITY_GATE%)"
    echo "   Fix issues before claiming completion."
    echo ""
    echo "Report: $VALIDATION_REPORT"
    exit 1
fi

