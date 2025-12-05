#!/usr/bin/env zsh
# Test /api/wo_status endpoint

set -euo pipefail

GATEWAY_URL="http://localhost:5001"
RELAY_KEY=$(grep RELAY_KEY ~/02luka/.env.local | cut -d'=' -f2 | tr -d '"' 2>/dev/null || echo "")

if [[ -z "$RELAY_KEY" ]]; then
  echo "⚠️  RELAY_KEY not found in .env.local, proceeding without auth"
  AUTH_HEADER=""
else
  AUTH_HEADER="X-Relay-Key: $RELAY_KEY"
fi

echo "🧪 Testing /api/wo_status endpoint"
echo "=================================="
echo ""

# Test 1: List all (default)
echo "Test 1: List all WOs (default limit=50)"
if [[ -n "$AUTH_HEADER" ]]; then
  COUNT=$(curl -s -H "$AUTH_HEADER" "$GATEWAY_URL/api/wo_status?limit=10" | jq -r '.items | length' 2>/dev/null || echo "0")
else
  COUNT=$(curl -s "$GATEWAY_URL/api/wo_status?limit=10" | jq -r '.items | length' 2>/dev/null || echo "0")
fi
echo "   Found $COUNT WOs"
echo ""

# Test 2: Filter by status
echo "Test 2: Filter by status=ERROR"
if [[ -n "$AUTH_HEADER" ]]; then
  STATUSES=$(curl -s -H "$AUTH_HEADER" "$GATEWAY_URL/api/wo_status?status=error" | jq -r '.items[].status' 2>/dev/null || echo "")
else
  STATUSES=$(curl -s "$GATEWAY_URL/api/wo_status?status=error" | jq -r '.items[].status' 2>/dev/null || echo "")
fi
if [[ -n "$STATUSES" ]]; then
  echo "$STATUSES" | while read wo_status; do
    echo "   Status: $wo_status"
  done
else
  echo "   No ERROR status WOs found"
fi
echo ""

# Test 3: Pagination
echo "Test 3: Pagination (offset=0, limit=3)"
if [[ -n "$AUTH_HEADER" ]]; then
  curl -s -H "$AUTH_HEADER" "$GATEWAY_URL/api/wo_status?offset=0&limit=3" | jq '{total, limit, offset, items_count: (.items | length)}' 2>/dev/null || echo "   Error parsing response"
else
  curl -s "$GATEWAY_URL/api/wo_status?offset=0&limit=3" | jq '{total, limit, offset, items_count: (.items | length)}' 2>/dev/null || echo "   Error parsing response"
fi
echo ""

# Test 4: Verify status enum
echo "Test 4: Verify status enum (should only be QUEUED|RUNNING|DONE|ERROR|STALE)"
if [[ -n "$AUTH_HEADER" ]]; then
  UNIQUE_STATUSES=$(curl -s -H "$AUTH_HEADER" "$GATEWAY_URL/api/wo_status?limit=50" | jq -r '.items[].status' 2>/dev/null | sort -u || echo "")
else
  UNIQUE_STATUSES=$(curl -s "$GATEWAY_URL/api/wo_status?limit=50" | jq -r '.items[].status' 2>/dev/null | sort -u || echo "")
fi
if [[ -n "$UNIQUE_STATUSES" ]]; then
  echo "$UNIQUE_STATUSES" | while read wo_status; do
    case "$wo_status" in
      QUEUED|RUNNING|DONE|ERROR|STALE)
        echo "   ✅ $wo_status (valid)"
        ;;
      *)
        echo "   ❌ $wo_status (INVALID - not in enum)"
        ;;
    esac
  done
else
  echo "   No WOs found to verify"
fi
echo ""

# Test 5: Response format
echo "Test 5: Verify response format"
if [[ -n "$AUTH_HEADER" ]]; then
  HAS_ITEMS=$(curl -s -H "$AUTH_HEADER" "$GATEWAY_URL/api/wo_status?limit=1" | jq -r 'has("items")' 2>/dev/null || echo "false")
  HAS_TOTAL=$(curl -s -H "$AUTH_HEADER" "$GATEWAY_URL/api/wo_status?limit=1" | jq -r 'has("total")' 2>/dev/null || echo "false")
else
  HAS_ITEMS=$(curl -s "$GATEWAY_URL/api/wo_status?limit=1" | jq -r 'has("items")' 2>/dev/null || echo "false")
  HAS_TOTAL=$(curl -s "$GATEWAY_URL/api/wo_status?limit=1" | jq -r 'has("total")' 2>/dev/null || echo "false")
fi

if [[ "$HAS_ITEMS" == "true" ]]; then
  echo "   ✅ Response has 'items' key"
else
  echo "   ❌ Response missing 'items' key"
fi

if [[ "$HAS_TOTAL" == "true" ]]; then
  echo "   ✅ Response has 'total' key"
else
  echo "   ❌ Response missing 'total' key"
fi
echo ""

echo "✅ Tests complete"
echo ""
echo "Note: If gateway is not running, start it with:"
echo "  cd ~/02luka/apps/opal_gateway && python gateway.py"
