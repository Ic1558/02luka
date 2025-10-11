#!/usr/bin/env bash
# Comprehensive smoke test for API, UI, and MCP services
# Tests all Linear-lite endpoints and core services
set -euo pipefail

# Source universal path resolver
source "$(dirname "$0")/../scripts/repo_root_resolver.sh"

echo "=== 02LUKA Smoke Test ==="
echo "Repository: $REPO_ROOT"
echo "Timestamp: $(date)"
echo ""

# Test counters
PASS=0
FAIL=0
WARN=0

# Helper function to test endpoints
test_endpoint() {
  local name="$1"
  local method="$2"
  local url="$3"
  local data="$4"
  local expected_status="${5:-200}"
  
  echo -n "Testing $name... "
  
  if [ "$method" = "GET" ]; then
    response=$(curl -s -w "%{http_code}" -o /tmp/smoke_response.json "$url" 2>/dev/null || echo "000")
  else
    response=$(curl -s -w "%{http_code}" -o /tmp/smoke_response.json -X "$method" -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null || echo "000")
  fi
  
  http_code="${response: -3}"
  
  if [ "$http_code" = "$expected_status" ]; then
    echo "✅ PASS ($http_code)"
    PASS=$((PASS + 1))
    return 0
  else
    echo "❌ FAIL ($http_code, expected $expected_status)"
    FAIL=$((FAIL + 1))
    return 1
  fi
}

# Test core services
echo "=== Core Services ==="

# API Capabilities
test_endpoint "API Capabilities" "GET" "http://127.0.0.1:4000/api/capabilities" "" "200" || true

# UI Accessibility  
test_endpoint "UI Index" "GET" "http://127.0.0.1:5173/" "" "200" || true
test_endpoint "UI Luka" "GET" "http://127.0.0.1:5173/luka.html" "" "200" || true

# MCP FS (optional)
echo -n "Testing MCP FS... "
if curl -s "http://127.0.0.1:8765/health" >/dev/null 2>&1; then
  echo "✅ PASS (online)"
  PASS=$((PASS + 1))
else
  echo "⚠️  WARN (offline - expected in devcontainer)"
  WARN=$((WARN + 1))
fi

echo ""

# Test Linear-lite API endpoints
echo "=== Linear-lite API Endpoints ==="

# Plan endpoint
test_endpoint "API Plan" "POST" "http://127.0.0.1:4000/api/plan" '{"goal":"test smoke check"}' "200" || true

# Patch endpoint (dry-run)
test_endpoint "API Patch" "POST" "http://127.0.0.1:4000/api/patch" '{"dryRun":true}' "200" || true

# Smoke endpoint
test_endpoint "API Smoke" "GET" "http://127.0.0.1:4000/api/smoke" "" "200" || true

echo ""

# Summary
echo "=== Smoke Test Summary ==="
echo "✅ PASS: $PASS"
echo "❌ FAIL: $FAIL" 
echo "⚠️  WARN: $WARN"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "🎉 All critical tests passed!"
  exit 0
else
  echo "💥 Some tests failed. Check service status."
  exit 1
fi
