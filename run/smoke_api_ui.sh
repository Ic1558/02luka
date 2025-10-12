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

# API Health
test_endpoint "API Health" "GET" "http://127.0.0.1:4000/healthz" "" "200" || true

# API Capabilities
test_endpoint "API Capabilities" "GET" "http://127.0.0.1:4000/api/capabilities" "" "200" || true

# Config discovery
test_endpoint "API Config" "GET" "http://127.0.0.1:4000/config.json" "" "200" || true

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

# Test Linear-lite API endpoints (optional for now)
echo "=== Linear-lite API Endpoints (Optional) ==="

# Plan endpoint (requires 'prompt' field)
test_endpoint "API Plan" "POST" "http://127.0.0.1:4000/api/plan" '{"prompt":"smoke test plan"}' "200" "true" || true

# Patch endpoint (requires 'patches' array, use dryRun mode)
test_endpoint "API Patch" "POST" "http://127.0.0.1:4000/api/patch" '{"patches":[],"dryRun":true}' "200" "true" || true

# Smoke endpoint (health check - should always pass)
test_endpoint "API Smoke" "GET" "http://127.0.0.1:4000/api/smoke" "" "200" "false" || true

echo ""

echo "=== Gateway Health ==="

echo -n "AI Gateway... "
ai_status=$(curl -s -w "%{http_code}" -o /tmp/smoke_ai_gateway.json -X POST "http://127.0.0.1:4000/api/ai/chat" -H "Content-Type: application/json" -d '{"health":true}' 2>/dev/null || echo "000")
ai_code="${ai_status: -3}"
if [ "$ai_code" = "200" ]; then
  echo "✅ AI gateway smoke OK"
  PASS=$((PASS + 1))
elif [ "$ai_code" = "503" ]; then
  echo "⚠️  AI gateway not configured"
  WARN=$((WARN + 1))
else
  echo "❌ AI gateway check failed ($ai_code)"
  FAIL=$((FAIL + 1))
fi

echo -n "Agents Gateway... "
agents_status=$(curl -s -w "%{http_code}" -o /tmp/smoke_agents_gateway.json "http://127.0.0.1:4000/api/agents/health" 2>/dev/null || echo "000")
agents_code="${agents_status: -3}"
if [ "$agents_code" = "200" ]; then
  echo "✅ Agents gateway health OK"
  PASS=$((PASS + 1))
elif [ "$agents_code" = "503" ]; then
  echo "⚠️  Agents gateway not configured"
  WARN=$((WARN + 1))
else
  echo "❌ Agents gateway check failed ($agents_code)"
  FAIL=$((FAIL + 1))
fi

echo ""

# Summary
echo "=== Smoke Test Summary ==="
echo "✅ PASS: $PASS"
echo "❌ FAIL: $FAIL" 
echo "⚠️  WARN: $WARN"
echo ""

# Only fail if core services fail
if [ $FAIL -eq 0 ]; then
  echo "🎉 All critical tests passed!"
  exit 0
else
  echo "💥 Core services failed. Check service status."
  exit 1
fi
