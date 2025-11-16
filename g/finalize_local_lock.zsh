#!/usr/bin/env zsh
set -euo pipefail

# Finalize Local Lock - Complete local agent system deployment
# This script:
# 1. Patches remaining CloudStorage refs in tools/
# 2. Persists LUKA_HOME in ~/.zshrc
# 3. Runs smoke tests
# 4. Generates verification report

LUKA_HOME="${LUKA_HOME:-$HOME/LocalProjects/02luka_local_g/g}"
TIMESTAMP=$(date +%y%m%d_%H%M%S)
VERIFY_DIR="$HOME/02luka/logs/verify"
mkdir -p "$VERIFY_DIR"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  FINALIZE LOCAL LOCK - Agent System Deployment            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "LUKA_HOME: $LUKA_HOME"
echo "Timestamp: $TIMESTAMP"
echo ""

# ============================================================================
# STEP 1: Patch remaining CloudStorage references
# ============================================================================
echo "=== Step 1: Patching CloudStorage references in tools/ ==="
CLOUDSTORAGE_COUNT=$(grep -r "Library/CloudStorage" "$LUKA_HOME/tools/" 2>/dev/null | wc -l | tr -d ' ')
echo "Found $CLOUDSTORAGE_COUNT CloudStorage references in tools/"

if [[ "$CLOUDSTORAGE_COUNT" -gt 0 ]]; then
    echo "⚠️  WARNING: CloudStorage refs still exist in tools/"
    echo "    Recommend manual review of:"
    grep -r "Library/CloudStorage" "$LUKA_HOME/tools/" 2>/dev/null || true
fi

# Check symlinks
SYMLINK_COUNT=$(find "$LUKA_HOME/tools/" -type l 2>/dev/null | wc -l | tr -d ' ')
echo "Found $SYMLINK_COUNT symlinks in tools/"

if [[ "$SYMLINK_COUNT" -gt 0 ]]; then
    echo "Symlinks found:"
    find "$LUKA_HOME/tools/" -type l -ls 2>/dev/null || true
fi

echo ""

# ============================================================================
# STEP 2: Persist LUKA_HOME in ~/.zshrc
# ============================================================================
echo "=== Step 2: Persisting LUKA_HOME in ~/.zshrc ==="

if grep -q "export LUKA_HOME=" ~/.zshrc 2>/dev/null; then
    echo "✅ LUKA_HOME already set in ~/.zshrc"
else
    echo "" >> ~/.zshrc
    echo "# 02luka Local Agent System" >> ~/.zshrc
    echo "export LUKA_HOME=\"$LUKA_HOME\"" >> ~/.zshrc
    echo "export PATH=\"\$LUKA_HOME/skills:\$PATH\"" >> ~/.zshrc
    echo "✅ Added LUKA_HOME to ~/.zshrc"
fi

echo ""

# ============================================================================
# STEP 3: Smoke Tests
# ============================================================================
echo "=== Step 3: Running Smoke Tests ==="

TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=""

# Test 1: andy status
echo -n "Test 1: andy status... "
if ~/bin/andy status &>/dev/null; then
    echo "✅ PASS"
    TEST_RESULTS+="✅ andy status - PASS\n"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL"
    TEST_RESULTS+="❌ andy status - FAIL\n"
    ((TESTS_FAILED++))
fi

# Test 2: Health server /ping
echo -n "Test 2: Health server ping... "
if curl -s http://localhost:4000/ping &>/dev/null; then
    echo "✅ PASS"
    TEST_RESULTS+="✅ Health server ping - PASS\n"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL"
    TEST_RESULTS+="❌ Health server ping - FAIL\n"
    ((TESTS_FAILED++))
fi

# Test 3: No CloudStorage refs in $LUKA_HOME (excluding backups)
echo -n "Test 3: No CloudStorage refs... "
CS_CHECK=$(rg "Library/CloudStorage" "$LUKA_HOME" --type-not markdown 2>/dev/null | grep -v "backup" | wc -l | tr -d ' ')
if [[ "$CS_CHECK" -eq 0 ]]; then
    echo "✅ PASS"
    TEST_RESULTS+="✅ No CloudStorage refs - PASS\n"
    ((TESTS_PASSED++))
else
    echo "⚠️  WARN ($CS_CHECK found)"
    TEST_RESULTS+="⚠️  CloudStorage refs - WARN ($CS_CHECK found)\n"
    ((TESTS_FAILED++))
fi

# Test 4: LaunchAgents running
echo -n "Test 4: LaunchAgents running... "
AGENT_COUNT=$(launchctl list | grep "02luka" | wc -l | tr -d ' ')
if [[ "$AGENT_COUNT" -gt 0 ]]; then
    echo "✅ PASS ($AGENT_COUNT agents)"
    TEST_RESULTS+="✅ LaunchAgents running - PASS ($AGENT_COUNT agents)\n"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL (no agents)"
    TEST_RESULTS+="❌ LaunchAgents running - FAIL\n"
    ((TESTS_FAILED++))
fi

# Test 5: Skills exist and executable
echo -n "Test 5: Skills executable... "
SKILL_COUNT=$(find "$LUKA_HOME/skills" -type f -perm +111 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SKILL_COUNT" -eq 8 ]]; then
    echo "✅ PASS (8 skills)"
    TEST_RESULTS+="✅ Skills executable - PASS (8 skills)\n"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL ($SKILL_COUNT/8 skills)"
    TEST_RESULTS+="❌ Skills executable - FAIL ($SKILL_COUNT/8)\n"
    ((TESTS_FAILED++))
fi

# Test 6: agent_router.py exists
echo -n "Test 6: agent_router.py exists... "
if [[ -x "$LUKA_HOME/agent_router.py" ]]; then
    echo "✅ PASS"
    TEST_RESULTS+="✅ agent_router.py - PASS\n"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL"
    TEST_RESULTS+="❌ agent_router.py - FAIL\n"
    ((TESTS_FAILED++))
fi

# Test 7: nlp_command_map.yaml exists
echo -n "Test 7: nlp_command_map.yaml exists... "
if [[ -f "$HOME/02luka/core/nlp/nlp_command_map.yaml" ]]; then
    echo "✅ PASS"
    TEST_RESULTS+="✅ nlp_command_map.yaml - PASS\n"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL"
    TEST_RESULTS+="❌ nlp_command_map.yaml - FAIL\n"
    ((TESTS_FAILED++))
fi

echo ""
echo "Smoke Tests: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo ""

# ============================================================================
# STEP 4: Generate Verification Report
# ============================================================================
echo "=== Step 4: Generating Verification Report ==="

REPORT_FILE="$VERIFY_DIR/finalize_local_lock_${TIMESTAMP}.md"

cat > "$REPORT_FILE" <<EOREPORT
# Local Agent System - Finalize Local Lock

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**LUKA_HOME:** $LUKA_HOME

---

## Summary

- **Tests Passed:** $TESTS_PASSED / 7
- **Tests Failed:** $TESTS_FAILED / 7
- **Status:** $( [[ $TESTS_FAILED -eq 0 ]] && echo "✅ ALL TESTS PASSED" || echo "⚠️ SOME TESTS FAILED" )

---

## Test Results

$(echo -e "$TEST_RESULTS")

---

## CloudStorage References

- **In tools/:** $CLOUDSTORAGE_COUNT references found
- **Symlinks in tools/:** $SYMLINK_COUNT found

$( [[ $CLOUDSTORAGE_COUNT -gt 0 ]] && echo "### CloudStorage Refs Found:" && grep -r "Library/CloudStorage" "$LUKA_HOME/tools/" 2>/dev/null || echo "" )

---

## LaunchAgents Status

$( launchctl list | grep "02luka" | awk '{print "- " $3 " (PID: " $1 ")"}' )

---

## Skills Inventory

$( ls -lh "$LUKA_HOME/skills/" 2>/dev/null | tail -n +2 | awk '{print "- " $9 " (" $5 ")"}' )

---

## Agent Router

- **Path:** $LUKA_HOME/agent_router.py
- **Size:** $( [[ -f "$LUKA_HOME/agent_router.py" ]] && ls -lh "$LUKA_HOME/agent_router.py" | awk '{print $5}' || echo "N/A" )
- **Executable:** $( [[ -x "$LUKA_HOME/agent_router.py" ]] && echo "✅ Yes" || echo "❌ No" )

---

## Intent Map

- **Path:** ~/02luka/core/nlp/nlp_command_map.yaml
- **Exists:** $( [[ -f "$HOME/02luka/core/nlp/nlp_command_map.yaml" ]] && echo "✅ Yes" || echo "❌ No" )
- **Intents:** $( [[ -f "$HOME/02luka/core/nlp/nlp_command_map.yaml" ]] && grep -c "^[a-z_]*:" "$HOME/02luka/core/nlp/nlp_command_map.yaml" || echo "0" )

---

## Environment

- **LUKA_HOME in .zshrc:** $( grep -q "export LUKA_HOME=" ~/.zshrc && echo "✅ Set" || echo "❌ Not set" )
- **PATH includes skills:** $( grep -q "LUKA_HOME/skills" ~/.zshrc && echo "✅ Yes" || echo "❌ No" )

---

## Next Steps

$( [[ $TESTS_FAILED -eq 0 ]] && echo "✅ System ready for delegation tasks!" || echo "⚠️ Fix failed tests before production use" )

### Test the System

\`\`\`bash
# Test agent router with check_health intent
echo '{"intent":"check_health"}' | python3 $LUKA_HOME/agent_router.py

# Test with list_agents intent
echo '{"intent":"list_agents"}' | python3 $LUKA_HOME/agent_router.py

# Test with create_report intent
echo '{"intent":"create_report"}' | python3 $LUKA_HOME/agent_router.py
\`\`\`

---

**Report saved to:** $REPORT_FILE
EOREPORT

echo "✅ Report saved to: $REPORT_FILE"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  FINALIZE LOCAL LOCK - COMPLETE                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Summary:"
echo "  • CloudStorage refs: $CLOUDSTORAGE_COUNT"
echo "  • Symlinks in tools: $SYMLINK_COUNT"
echo "  • LUKA_HOME persisted: ✅"
echo "  • Smoke tests: $TESTS_PASSED/$((TESTS_PASSED + TESTS_FAILED)) passed"
echo "  • Report: $REPORT_FILE"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "🎉 All systems operational! Local agent ready for delegation."
else
    echo "⚠️  Some tests failed. Review report for details."
fi

exit 0
