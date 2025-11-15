#!/usr/bin/env zsh
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to run the WO dashboard reality check." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required to run the WO dashboard reality check." >&2
  exit 1
fi

BASE_URL="${DASHBOARD_URL:-http://localhost:8080}"

check_endpoint() {
  local endpoint="$1"
  local description="$2"
  if ! response=$(curl -fsS "${BASE_URL}${endpoint}"); then
    echo "Error: Failed to fetch ${description} at ${BASE_URL}${endpoint}." >&2
    exit 1
  fi
  echo "$response"
}

validate_wos() {
  local payload
  payload=$(check_endpoint "/api/wos" "WO list")
  echo "$payload" | jq -e 'type == "array" or type == "object"' >/dev/null
}

validate_services() {
  local payload
  payload=$(check_endpoint "/api/services" "services summary")
  echo "$payload" | jq -e '
    (.summary | type == "object") and (.summary | has("total")) and
    (.services | type == "array")
  ' >/dev/null
}

validate_mls() {
  local payload
  payload=$(check_endpoint "/api/mls" "MLS summary")
  echo "$payload" | jq -e '
    (.entries | type == "array") and
    (.summary | type == "object") and (.summary | has("total"))
  ' >/dev/null
}

validate_wos
validate_services
validate_mls

echo "WO dashboard reality check passed for ${BASE_URL}."
