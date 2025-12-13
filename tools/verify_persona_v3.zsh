#!/usr/bin/env zsh
# verify_persona_v3.zsh
# Verification script for Persona Loader v3 - Cross-engine Consistency Check

set -uo pipefail

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
PERSONA_LOADER="${LUKA_BASE}/tools/load_persona_v3.zsh"
CLS_ID_FILE="${LUKA_BASE}/CLS.md"
AG_BRAIN_ROOT="${HOME}/.gemini/antigravity/brain"
PERSONA_DIR="${LUKA_BASE}/personas"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Persona Loader v3 - Verification Suite"
echo "========================================"
echo ""

# Test 1: Cursor Injection
echo "Test 1: Cursor CLS Injection"
echo "----------------------------"
if [[ ! -f "$PERSONA_LOADER" ]]; then
  echo -e "${RED}❌ FAILED${NC}: Persona loader not found: $PERSONA_LOADER"
  ((TESTS_FAILED++))
  FAILED_TESTS+=("Test 1: Cursor injection")
else
  # Run persona loader for Cursor
  if zsh "$PERSONA_LOADER" cls cursor 2>&1; then
    # Verify CLS.md exists and contains persona content
    if [[ -f "$CLS_ID_FILE" ]]; then
      if grep -q "CLS" "$CLS_ID_FILE" && grep -q "System Architect" "$CLS_ID_FILE"; then
        echo -e "${GREEN}✅ PASS${NC}: CLS.md contains persona content"
        ((TESTS_PASSED++))
      else
        echo -e "${RED}❌ FAILED${NC}: CLS.md exists but missing expected content"
        ((TESTS_FAILED++))
        FAILED_TESTS+=("Test 1: Cursor content verification")
      fi
    else
      echo -e "${RED}❌ FAILED${NC}: CLS.md was not created"
      ((TESTS_FAILED++))
      FAILED_TESTS+=("Test 1: Cursor file creation")
    fi
  else
    echo -e "${RED}❌ FAILED${NC}: Persona loader execution failed"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("Test 1: Cursor injection")
  fi
fi
echo ""

# Test 2: Antigravity Injection (requires active session)
echo "Test 2: Antigravity Liam Injection"
echo "----------------------------------"
if [[ ! -d "$AG_BRAIN_ROOT" ]]; then
  echo -e "${YELLOW}⚠️  SKIPPED${NC}: Antigravity brain directory not found"
  echo "   (Open Antigravity.app and start a session first)"
  echo ""
else
  # Find latest brain directory
  local latest
  latest="$(ls -td "$AG_BRAIN_ROOT"/*/ 2>/dev/null | head -1 || true)"
  
  if [[ -z "${latest:-}" ]]; then
    echo -e "${YELLOW}⚠️  SKIPPED${NC}: No Antigravity brain sessions found"
    echo "   (Open Antigravity.app and start a session first)"
    echo ""
  else
    # Run persona loader for Antigravity
    if zsh "$PERSONA_LOADER" liam ag 2>&1; then
      local persona_file="${latest}00_ACTIVE_PERSONA_LIAM.md"
      local context_file="${latest}01_CONTEXT_SUMMARY.md"
      local task_file="${latest}task.md"
      
      local all_ok=true
      
      # Check persona file
      if [[ -f "$persona_file" ]]; then
        if grep -q "LIAM" "$persona_file" && grep -q "Explorer" "$persona_file"; then
          echo -e "${GREEN}✅ PASS${NC}: 00_ACTIVE_PERSONA_LIAM.md exists with content"
        else
          echo -e "${RED}❌ FAILED${NC}: Persona file missing expected content"
          all_ok=false
        fi
      else
        echo -e "${RED}❌ FAILED${NC}: Persona file not created: $persona_file"
        all_ok=false
      fi
      
      # Check context summary file
      if [[ -f "$context_file" ]]; then
        if grep -q "Two Worlds" "$context_file" && grep -q "Locked Zones" "$context_file"; then
          echo -e "${GREEN}✅ PASS${NC}: 01_CONTEXT_SUMMARY.md exists with governance content"
        else
          echo -e "${RED}❌ FAILED${NC}: Context summary missing expected governance content"
          all_ok=false
        fi
      else
        echo -e "${RED}❌ FAILED${NC}: Context summary not created: $context_file"
        all_ok=false
      fi
      
      # Check task.md reference
      if [[ -f "$task_file" ]]; then
        if grep -q "00_ACTIVE_PERSONA_LIAM.md" "$task_file" && grep -q "01_CONTEXT_SUMMARY.md" "$task_file"; then
          echo -e "${GREEN}✅ PASS${NC}: task.md references both persona and context files"
        else
          echo -e "${YELLOW}⚠️  WARNING${NC}: task.md may not reference persona files (non-critical)"
        fi
      fi
      
      if [[ "$all_ok" == true ]]; then
        ((TESTS_PASSED++))
      else
        ((TESTS_FAILED++))
        FAILED_TESTS+=("Test 2: Antigravity injection")
      fi
    else
      echo -e "${RED}❌ FAILED${NC}: Persona loader execution failed for Antigravity"
      ((TESTS_FAILED++))
      FAILED_TESTS+=("Test 2: Antigravity injection")
    fi
  fi
fi
echo ""

# Test 3: Context Summary Content Verification
echo "Test 3: Context Summary Content"
echo "-------------------------------"
if [[ -d "$AG_BRAIN_ROOT" ]]; then
  local latest
  latest="$(ls -td "$AG_BRAIN_ROOT"/*/ 2>/dev/null | head -1 || true)"
  
  if [[ -n "${latest:-}" ]] && [[ -f "${latest}01_CONTEXT_SUMMARY.md" ]]; then
    local context_file="${latest}01_CONTEXT_SUMMARY.md"
    local content_ok=true
    
    # Check for required sections
    local required_sections=(
      "Two Worlds"
      "Locked Zones"
      "Open Zones"
      "Role Matrix"
      "Work Order"
      "AI_OP_001_v4.md"
    )
    
    for section in "${required_sections[@]}"; do
      if grep -qi "$section" "$context_file"; then
        echo -e "  ${GREEN}✓${NC} Contains: $section"
      else
        echo -e "  ${RED}✗${NC} Missing: $section"
        content_ok=false
      fi
    done
    
    if [[ "$content_ok" == true ]]; then
      echo -e "${GREEN}✅ PASS${NC}: Context summary contains all required governance elements"
      ((TESTS_PASSED++))
    else
      echo -e "${RED}❌ FAILED${NC}: Context summary missing required content"
      ((TESTS_FAILED++))
      FAILED_TESTS+=("Test 3: Context summary content")
    fi
  else
    echo -e "${YELLOW}⚠️  SKIPPED${NC}: No Antigravity session or context summary found"
    echo "   (Run Test 2 first to create context summary)"
  fi
else
  echo -e "${YELLOW}⚠️  SKIPPED${NC}: Antigravity brain directory not found"
fi
echo ""

# Test 4: Cross-engine Consistency
echo "Test 4: Cross-engine Consistency"
echo "-------------------------------"
if [[ -f "$CLS_ID_FILE" ]] && [[ -d "$AG_BRAIN_ROOT" ]]; then
  local latest
  latest="$(ls -td "$AG_BRAIN_ROOT"/*/ 2>/dev/null | head -1 || true)"
  
  if [[ -n "${latest:-}" ]] && [[ -f "${latest}01_CONTEXT_SUMMARY.md" ]]; then
    local context_file="${latest}01_CONTEXT_SUMMARY.md"
    local consistency_ok=true
    
    # Check that both Cursor and Antigravity have governance references
    if grep -q "GOVERNANCE_CLI_VS_BACKGROUND" "$CLS_ID_FILE" && grep -q "GOVERNANCE_CLI_VS_BACKGROUND" "$context_file"; then
      echo -e "  ${GREEN}✓${NC} Both engines reference governance docs"
    else
      echo -e "  ${RED}✗${NC} Governance references inconsistent"
      consistency_ok=false
    fi
    
    # Check that both mention Two Worlds
    if grep -q "Two Worlds" "$CLS_ID_FILE" && grep -q "Two Worlds" "$context_file"; then
      echo -e "  ${GREEN}✓${NC} Both engines understand Two Worlds model"
    else
      echo -e "  ${RED}✗${NC} Two Worlds model not consistent"
      consistency_ok=false
    fi
    
    if [[ "$consistency_ok" == true ]]; then
      echo -e "${GREEN}✅ PASS${NC}: Cross-engine consistency verified"
      ((TESTS_PASSED++))
    else
      echo -e "${RED}❌ FAILED${NC}: Cross-engine consistency issues found"
      ((TESTS_FAILED++))
      FAILED_TESTS+=("Test 4: Cross-engine consistency")
    fi
  else
    echo -e "${YELLOW}⚠️  SKIPPED${NC}: Cannot verify without Antigravity session"
  fi
else
  echo -e "${YELLOW}⚠️  SKIPPED${NC}: Cannot verify without both Cursor and Antigravity data"
fi
echo ""

# Summary
echo "========================================"
echo "📊 Verification Results:"
echo "   Passed: $TESTS_PASSED"
echo "   Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✅ All verification tests passed! Persona Loader v3 is working correctly.${NC}"
  exit 0
else
  echo -e "${RED}❌ $TESTS_FAILED test(s) failed:${NC}"
  for test in "${FAILED_TESTS[@]}"; do
    echo "   - $test"
  done
  exit 1
fi
