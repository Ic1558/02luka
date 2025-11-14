#!/usr/bin/env bash
# Phase 21 Comprehensive Verification Script
# Tests all three Phase 21 components across their branches

set -euo pipefail

SID="011CUvQ8F4cVZPzH4rT1a1cM"
ORIGINAL_BRANCH=$(git branch --show-current)

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║       Phase 21: Hub Infrastructure — Verification Suite          ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success=0
failure=0

test_result() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: $2"
    ((success++))
  else
    echo -e "${RED}✗ FAIL${NC}: $2"
    ((failure++))
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  PHASE 21.1 — Hub Mini UI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Switching to branch: claude/phase-21-1-hub-mini-ui-${SID}"
git switch "claude/phase-21-1-hub-mini-ui-${SID}" 2>/dev/null || { echo "Branch not found"; exit 1; }

echo "Checking files..."
if test -f hub/ui/index.html; then test_result 0 "hub/ui/index.html exists"; else test_result 1 "hub/ui/index.html exists"; fi
if test -f hub/ui/app.js; then test_result 0 "hub/ui/app.js exists"; else test_result 1 "hub/ui/app.js exists"; fi
if test -f hub/ui/style.css; then test_result 0 "hub/ui/style.css exists"; else test_result 1 "hub/ui/style.css exists"; fi
if test -x tools/hub_http.zsh; then test_result 0 "tools/hub_http.zsh executable"; else test_result 1 "tools/hub_http.zsh executable"; fi
if test -f .github/workflows/hub-ui-check.yml; then test_result 0 "hub-ui-check.yml exists"; else test_result 1 "hub-ui-check.yml exists"; fi

echo "Validating HTML structure..."
if grep -q "<!doctype html>" hub/ui/index.html; then test_result 0 "HTML DOCTYPE present"; else test_result 1 "HTML DOCTYPE present"; fi
if grep -q "02LUKA Hub" hub/ui/index.html; then test_result 0 "Page title correct"; else test_result 1 "Page title correct"; fi

echo "Validating JavaScript..."
if grep -q "safeJson" hub/ui/app.js; then test_result 0 "safeJson function defined"; else test_result 1 "safeJson function defined"; fi
if grep -q "fetch" hub/ui/app.js; then test_result 0 "Fetch API used"; else test_result 1 "Fetch API used"; fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  PHASE 21.2 — Memory Guard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Switching to branch: claude/phase-21-2-memory-guard-${SID}"
git switch "claude/phase-21-2-memory-guard-${SID}" 2>/dev/null || { echo "Branch not found"; exit 1; }

echo "Checking files..."
if test -f config/memory_guard.yaml; then test_result 0 "memory_guard.yaml exists"; else test_result 1 "memory_guard.yaml exists"; fi
if test -f config/schemas/memory_guard.schema.json; then test_result 0 "memory_guard schema exists"; else test_result 1 "memory_guard schema exists"; fi
if test -x tools/check_memory_guard.zsh; then test_result 0 "check_memory_guard.zsh executable"; else test_result 1 "check_memory_guard.zsh executable"; fi
if test -f .github/workflows/memory-guard.yml; then test_result 0 "memory-guard.yml exists"; else test_result 1 "memory-guard.yml exists"; fi

echo "Validating configuration..."
if grep -q "warn_mb: 10" config/memory_guard.yaml; then test_result 0 "Warn threshold = 10MB"; else test_result 1 "Warn threshold = 10MB"; fi
if grep -q "fail_mb: 25" config/memory_guard.yaml; then test_result 0 "Fail threshold = 25MB"; else test_result 1 "Fail threshold = 25MB"; fi
if grep -q "node_modules" config/memory_guard.yaml; then test_result 0 "node_modules in deny list"; else test_result 1 "node_modules in deny list"; fi

echo "Validating JSON schema..."
command -v jq >/dev/null 2>&1 && {
  jq -e . config/schemas/memory_guard.schema.json >/dev/null 2>&1 && \
    test_result 0 "JSON schema is valid" || test_result 1 "JSON schema is valid"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  PHASE 21.3 — Protection Enforcer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Switching to branch: claude/phase-21-3-protection-enforcer-${SID}"
git switch "claude/phase-21-3-protection-enforcer-${SID}" 2>/dev/null || { echo "Branch not found"; exit 1; }

echo "Checking files..."
if test -f config/required_checks.json; then test_result 0 "required_checks.json exists"; else test_result 1 "required_checks.json exists"; fi
if test -f tools/required_checks_assert.mjs; then test_result 0 "required_checks_assert.mjs exists"; else test_result 1 "required_checks_assert.mjs exists"; fi
if test -f .github/workflows/protection-enforcer.yml; then test_result 0 "protection-enforcer.yml exists"; else test_result 1 "protection-enforcer.yml exists"; fi

echo "Validating configuration..."
command -v jq >/dev/null 2>&1 && {
  jq -e '.required | length > 0' config/required_checks.json >/dev/null 2>&1 && \
    test_result 0 "Required checks array not empty" || test_result 1 "Required checks array not empty"
  jq -e '.required | contains(["path-guard"])' config/required_checks.json >/dev/null 2>&1 && \
    test_result 0 "path-guard in required checks" || test_result 1 "path-guard in required checks"
}

echo "Testing assertion script..."
command -v node >/dev/null 2>&1 && {
  node tools/required_checks_assert.mjs >/dev/null 2>&1 && \
    test_result 0 "Assertion script runs successfully" || test_result 1 "Assertion script runs successfully"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESULTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${GREEN}Passed:${NC} $success"
echo -e "  ${RED}Failed:${NC} $failure"
echo ""

if [ $failure -eq 0 ]; then
  echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
  echo "Phase 21 implementation is complete and verified!"
else
  echo -e "${YELLOW}⚠ SOME TESTS FAILED${NC}"
  echo "Please review the failures above."
fi

echo ""
echo "Returning to original branch: $ORIGINAL_BRANCH"
git switch "$ORIGINAL_BRANCH" 2>/dev/null || git switch main

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next step: Run ./tools/create_phase21_prs.sh to view PR creation info"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit $failure
