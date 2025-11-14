#!/usr/bin/env zsh

set -euo pipefail

BASE_URL="http://localhost:8765"
AUTH_TOKEN="${DASHBOARD_AUTH_TOKEN:-dashboard-token-change-me}"

echo "== WO Dashboard Security Integration Tests =="
echo "Base URL: $BASE_URL"
echo "Auth Token: ${AUTH_TOKEN:0:10}..."
echo

fail=0

run_test() {
  local name="$1"
  local url="$2"
  local expected_codes="$3"   # space-separated list, e.g. "400" หรือ "200 404"
  local use_auth="${4:-true}"  # default: use auth token

  echo "▶ $name"
  
  if [ "$use_auth" = "true" ]; then
    http_code="$(curl -s -o /dev/null -w '%{http_code}' \
      -H "Authorization: Bearer $AUTH_TOKEN" \
      "$url" || echo "000")"
  else
    http_code="$(curl -s -o /dev/null -w '%{http_code}' \
      "$url" || echo "000")"
  fi

  if print -- "$expected_codes" | grep -q "\b$http_code\b"; then
    echo "   ✅ got $http_code (expected: $expected_codes)"
  else
    echo "   ❌ got $http_code (expected: $expected_codes)"
    fail=1
  fi

  echo
}

# 1) Path traversal prevention (ควร 400 หรือ 404 - ทั้งสองปลอดภัย)
run_test "Path traversal blocked" \
  "$BASE_URL/api/wo/../../../../etc/passwd" \
  "400 404" \
  "true"

# 2) Removed auth token endpoint (ควร 404) - ไม่ต้องส่ง auth token
run_test "/api/auth-token removed" \
  "$BASE_URL/api/auth-token" \
  "404" \
  "false"

# 3) Invalid characters (ควร 400)
run_test "Invalid characters in ID" \
  "$BASE_URL/api/wo/invalid!!id" \
  "400" \
  "true"

# 4) Length limit (ยาวเกินไป → 400 หรือ 404 - ทั้งสองปลอดภัย)
long_id="$(printf 'a%.0s' {1..300})"
run_test "Overlength ID rejected" \
  "$BASE_URL/api/wo/$long_id" \
  "400 404" \
  "true"

# 5) Valid ID format (ไม่มี guarantee ว่ามี state → 200 หรือ 404 ถือว่าปกติ)
run_test "Valid-format ID (200/404 ok)" \
  "$BASE_URL/api/wo/test-valid-123" \
  "200 404" \
  "true"

# 6) Empty ID (route ผิดรูป → 400 เป็นเป้าหมาย แต่ 404 ยังถือว่าปลอดภัย)
run_test "Empty ID rejected" \
  "$BASE_URL/api/wo/" \
  "400 404" \
  "true"

echo "============================================="
if [ "$fail" -eq 0 ]; then
  echo "✅ All security integration tests passed (or safely handled)."
  exit 0
else
  echo "❌ Some security tests FAILED – check server logs and handlers."
  exit 1
fi
