#!/bin/bash
set -euo pipefail

# boss-api v2.0 Verification Script
# Tests all v1 and v2 endpoints

WORKER_URL="https://boss-api.ittipong-c.workers.dev"
PASS=0
FAIL=0

echo "========================================"
echo "boss-api v2.0 Verification"
echo "========================================"
echo ""
echo "Worker URL: $WORKER_URL"
echo "Timestamp: $(date -u +%Y%m%dT%H%M%SZ)"
echo ""

# Test helper
test_endpoint() {
  local name="$1"
  local url="$2"
  local expected_key="$3"

  echo -n "Testing $name... "

  if response=$(curl -s "$url" 2>&1); then
    if echo "$response" | jq -e ".$expected_key" >/dev/null 2>&1; then
      echo "✅ PASS"
      ((PASS++))
      return 0
    else
      echo "❌ FAIL (missing key: $expected_key)"
      echo "   Response: $response"
      ((FAIL++))
      return 1
    fi
  else
    echo "❌ FAIL (connection error)"
    ((FAIL++))
    return 1
  fi
}

echo "========================================="
echo "V1 Endpoints (Backward Compatibility)"
echo "========================================="
echo ""

# V1: Health check
test_endpoint "GET /healthz" "$WORKER_URL/healthz" "status"

# V1: Capabilities
test_endpoint "GET /api/capabilities" "$WORKER_URL/api/capabilities" "endpoints"

# V1: Reports summary
test_endpoint "GET /api/reports/summary" "$WORKER_URL/api/reports/summary" "status"

# V1: Reports list
test_endpoint "GET /api/reports/list" "$WORKER_URL/api/reports/list" "files"

echo ""
echo "========================================="
echo "V2 Endpoints (New)"
echo "========================================="
echo ""

# V2: Runs list
test_endpoint "GET /api/v2/runs" "$WORKER_URL/api/v2/runs?limit=5" "runs"

# V2: Memory list
test_endpoint "GET /api/v2/memory" "$WORKER_URL/api/v2/memory?agent=gc&limit=5" "memories"

# V2: Telemetry
test_endpoint "GET /api/v2/telemetry" "$WORKER_URL/api/v2/telemetry?source=system_health" "source"

# V2: Approvals
test_endpoint "GET /api/v2/approvals" "$WORKER_URL/api/v2/approvals" "approvals"

echo ""
echo "========================================="
echo "Version Check"
echo "========================================="
echo ""

VERSION=$(curl -s "$WORKER_URL/healthz" | jq -r '.version')
if [ "$VERSION" = "2.0" ]; then
  echo "✅ Version check: $VERSION"
  ((PASS++))
else
  echo "❌ Version check: Expected 2.0, got $VERSION"
  ((FAIL++))
fi

echo ""
echo "========================================="
echo "Capabilities Check"
echo "========================================="
echo ""

# Check if v2 endpoints are listed in capabilities
CAPS=$(curl -s "$WORKER_URL/api/capabilities" | jq -r '.endpoints.v2')
if [ "$CAPS" != "null" ]; then
  echo "✅ V2 endpoints in capabilities"
  ((PASS++))
else
  echo "❌ V2 endpoints missing from capabilities"
  ((FAIL++))
fi

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo ""
echo "Total tests: $((PASS + FAIL))"
echo "Passed: $PASS ✅"
echo "Failed: $FAIL ❌"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "🎉 All tests PASSED! boss-api v2.0 is fully operational."
  exit 0
else
  echo "⚠️  Some tests FAILED. Please review the output above."
  exit 1
fi
