#!/usr/bin/env bash
# Comprehensive smoke test for API, UI, and MCP services
# Tests all Linear-lite endpoints and core services
set -euo pipefail

# Source universal path resolver
source "$(dirname "$0")/../scripts/repo_root_resolver.sh"

# Capture start time for telemetry (milliseconds since epoch)
START_TIME=$(($(date +%s) * 1000))

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

# Agents Gateway Health
test_endpoint "Agents Gateway Health" "GET" "http://127.0.0.1:4000/api/agents/health" "" "200" || true

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
echo "=== Discord Integration (Optional) ==="
if [ "${SMOKE_SKIP_DISCORD_NOTIFY:-0}" = "1" ]; then
  echo "Discord Notify... SKIP (disabled by SMOKE_SKIP_DISCORD_NOTIFY=1)"
elif [ -n "${DISCORD_WEBHOOK_DEFAULT:-}" ] || [ -n "${DISCORD_WEBHOOK_MAP:-}" ]; then
  echo -n "Discord Notify... "
  payload='{"content":"02LUKA smoke check","level":"info","channel":"default"}'
  response=$(curl -s -m "5" -w "%{http_code}" -o /tmp/smoke_response.json -X "POST" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "http://127.0.0.1:4000/api/discord/notify" 2>/dev/null || echo "000")
  http_code="${response: -3}"
  if [ "$http_code" = "200" ]; then
    echo "PASS ✅ ($http_code)"
    PASS=$((PASS + 1))
  elif [ "$http_code" = "503" ]; then
    echo "SKIP (webhook bridge not ready)"
  else
    echo "FAIL ❌ ($http_code, expected 200)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "Discord Notify... SKIP (webhook not configured)"
fi

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "WARN: $WARN"
echo "FAIL: $FAIL"

# Record telemetry
END_TIME=$(($(date +%s) * 1000))
DURATION=$((END_TIME - START_TIME))

if command -v node >/dev/null 2>&1; then
  node "$REPO_ROOT/boss-api/telemetry.cjs" \
    --task smoke_api_ui \
    --pass "$PASS" \
    --warn "$WARN" \
    --fail "$FAIL" \
    --duration "$DURATION" >/dev/null 2>&1 || true
fi

# Record in vector memory (successful runs only)
if [ "$FAIL" -eq 0 ] && command -v node >/dev/null 2>&1; then
  memory_text="Smoke test completed successfully. Results: PASS=$PASS WARN=$WARN FAIL=$FAIL. Duration: ${DURATION}ms."
  node "$REPO_ROOT/memory/index.cjs" --remember solution "$memory_text" >/dev/null 2>&1 || true
fi

# Exit with appropriate code
if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
