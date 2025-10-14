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
  local is_optional="${6:-false}"
  local timeout="${7:-10}"

  echo -n "Testing $name... "

  if [ "$method" = "GET" ]; then
    response=$(curl -s -m "$timeout" -w "%{http_code}" -o /tmp/smoke_response.json "$url" 2>/dev/null || echo "000")
  else
    response=$(curl -s -m "$timeout" -w "%{http_code}" -o /tmp/smoke_response.json -X "$method" -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null || echo "000")
  fi

  http_code="${response: -3}"

  if [ "$http_code" = "$expected_status" ]; then
    echo "✅ PASS ($http_code)"
    PASS=$((PASS + 1))
    return 0
  else
    if [ "$is_optional" = "true" ]; then
      echo "⚠️  WARN ($http_code, expected $expected_status - optional endpoint)"
      WARN=$((WARN + 1))
    else
      echo "❌ FAIL ($http_code, expected $expected_status)"
      FAIL=$((FAIL + 1))
    fi
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

# Test Linear-lite API endpoints (all optional for now)
echo "=== Linear-lite API Endpoints (Optional) ==="

# Plan endpoint (stub mode for fast smoke test)
test_endpoint "API Plan" "POST" "http://127.0.0.1:4000/api/plan" '{"goal":"ping","stub":true}' "200" "true" "3" || true

# Patch endpoint (dry-run)
test_endpoint "API Patch" "POST" "http://127.0.0.1:4000/api/patch" '{"dryRun":true}' "200" "true" "5" || true

# Smoke endpoint
test_endpoint "API Smoke" "GET" "http://127.0.0.1:4000/api/smoke" "" "200" "true" "5" || true

echo ""

echo "=== Paula API (Optional) ==="
test_endpoint "Paula Health" "GET" "http://127.0.0.1:4000/api/paula/health" "" "200" "true" || true

echo ""

# Summary
echo "=== Smoke Test Summary ==="
echo "✅ PASS: $PASS"
echo "❌ FAIL: $FAIL" 
echo "⚠️  WARN: $WARN"
echo ""

# Only fail if core services fail (API capabilities, UI)
if [ $FAIL -eq 0 ]; then
  echo "🎉 All critical tests passed!"
  exit 0
else
  echo "💥 Some tests failed. Check service status."
  exit 1
fi
