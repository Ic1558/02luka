#!/usr/bin/env bash
# Comprehensive smoke test for API, UI, and MCP services
# Tests all Linear-lite endpoints and core services
set -euo pipefail

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'smoke')"
trap 'rm -rf "$TMP_DIR"' EXIT

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

# Paula tracking
PAULA_CRAWL_ACCEPTED="false"
PAULA_PAGES_OK="n/a"
PAULA_PAGES_DENIED="n/a"
PAULA_DUP_PERCENT="n/a"
PAULA_CORPUS_DOCS="n/a"
PAULA_CORPUS_DOMAINS="n/a"

record_paula_metrics() {
  local pages_ok="$1"
  local pages_denied="$2"
  local dup_percent="$3"

  if [ -n "$pages_ok" ]; then
    PAULA_PAGES_OK="$pages_ok"
  fi
  if [ -n "$pages_denied" ]; then
    PAULA_PAGES_DENIED="$pages_denied"
  fi
  if [ -n "$dup_percent" ]; then
    PAULA_DUP_PERCENT="$dup_percent"
  fi
}

record_paula_corpus() {
  local docs="$1"
  local domains="$2"

  if [ -n "$docs" ]; then
    PAULA_CORPUS_DOCS="$docs"
  fi
  if [ -n "$domains" ]; then
    PAULA_CORPUS_DOMAINS="$domains"
  fi
}

append_paula_log() {
  local log_dir="$REPO_ROOT/g/reports/runtime"
  local log_file="$log_dir/paula_crawl_log.md"

  mkdir -p "$log_dir"

  {
    echo "## $(date -u '+%Y-%m-%d %H:%M:%SZ')"
    echo ""
    echo "- accepted: $PAULA_CRAWL_ACCEPTED"
    echo "- pages_ok: $PAULA_PAGES_OK"
    echo "- pages_denied: $PAULA_PAGES_DENIED"
    echo "- dup_percent: $PAULA_DUP_PERCENT"
    echo "- corpus_docs: $PAULA_CORPUS_DOCS"
    echo "- corpus_domains: $PAULA_CORPUS_DOMAINS"
    echo "- result: $([ $FAIL -eq 0 ] && echo PASS || echo FAIL)"
    echo ""
    echo "---"
    echo ""
  } >>"$log_file"
}

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

test_paula_crawl() {
  local name="Paula Crawl (dry-run)"
  local url="http://127.0.0.1:4000/api/paula/crawl"
  local payload='{"dryRun":true,"seeds":["https://theedges.work"]}'
  local tmp_json="$TMP_DIR/paula_crawl.json"

  echo -n "Testing $name... "

  local response
  response=$(curl -s -w "%{http_code}" -o "$tmp_json" -X POST -H "Content-Type: application/json" -d "$payload" "$url" 2>/dev/null || echo "000")
  local http_code="${response: -3}"

  if [[ "$http_code" != "200" && "$http_code" != "202" ]]; then
    echo "❌ FAIL ($http_code, expected 200/202)"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local python_output
  if python_output=$(python3 - "$tmp_json" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception as exc:  # pragma: no cover - smoke safety
    print(f"error=invalid_json:{exc}")
    sys.exit(1)

if data.get("accepted") is not True:
    print("error=accepted_false")
    sys.exit(1)

def find_metric(keys):
    for key in keys:
        current = data
        missing = False
        for part in key.split('.'):
            if isinstance(current, dict) and part in current:
                current = current[part]
            elif isinstance(current, list):
                try:
                    idx = int(part)
                except (TypeError, ValueError):
                    missing = True
                    break
                if 0 <= idx < len(current):
                    current = current[idx]
                else:
                    missing = True
                    break
            else:
                missing = True
                break
        if not missing:
            return current
    return None

pages_ok = find_metric([
    "pages_ok",
    "summary.pages_ok",
    "summary.pages.ok",
    "metrics.pages_ok",
    "metrics.pages.ok",
    "pages.ok",
])

pages_denied = find_metric([
    "pages_denied",
    "summary.pages_denied",
    "summary.pages.denied",
    "metrics.pages_denied",
    "metrics.pages.denied",
    "pages.denied",
])

dup_percent = find_metric([
    "dup_percent",
    "duplicate_percent",
    "duplicates_percent",
    "summary.dup_percent",
    "summary.duplicate_percent",
    "metrics.dup_percent",
    "metrics.duplicate_percent",
])

def fmt(value):
    if value is None:
        return "n/a"
    if isinstance(value, float):
        return f"{value:.2f}"
    return str(value)

print(f"accepted=true")
print(f"pages_ok={fmt(pages_ok)}")
print(f"pages_denied={fmt(pages_denied)}")
print(f"dup_percent={fmt(dup_percent)}")
PY
  ); then
    PAULA_CRAWL_ACCEPTED="true"
    while IFS='=' read -r key value; do
      case "$key" in
        pages_ok) record_paula_metrics "$value" "" "" ;;
        pages_denied) record_paula_metrics "" "$value" "" ;;
        dup_percent) record_paula_metrics "" "" "$value" ;;
      esac
    done <<<"$python_output"
    echo "✅ PASS ($http_code, accepted true)"
    PASS=$((PASS + 1))
    return 0
  else
    echo "❌ FAIL ($http_code, accepted flag or payload invalid)"
    FAIL=$((FAIL + 1))
    return 1
  fi
}

test_paula_corpus_stats() {
  local name="Paula Corpus Stats"
  local url="http://127.0.0.1:4000/api/paula/corpus/stats"
  local tmp_json="$TMP_DIR/paula_corpus_stats.json"

  echo -n "Testing $name... "

  local response
  response=$(curl -s -w "%{http_code}" -o "$tmp_json" "$url" 2>/dev/null || echo "000")
  local http_code="${response: -3}"

  if [ "$http_code" != "200" ]; then
    echo "❌ FAIL ($http_code, expected 200)"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local python_output
  if python_output=$(python3 - "$tmp_json" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception as exc:  # pragma: no cover - smoke safety
    print(f"error=invalid_json:{exc}")
    sys.exit(1)

docs = data.get("docs")
domains = data.get("domains")

if not isinstance(docs, (int, float)) or docs < 0:
    print("error=docs_invalid")
    sys.exit(1)

if not isinstance(domains, list):
    print("error=domains_invalid")
    sys.exit(1)

print(f"docs={int(docs)}")
print(f"domains_count={len(domains)}")
PY
  ); then
    while IFS='=' read -r key value; do
      case "$key" in
        docs) record_paula_corpus "$value" "" ;;
        domains_count) record_paula_corpus "" "$value" ;;
      esac
    done <<<"$python_output"
    echo "✅ PASS ($http_code, docs/domains valid)"
    PASS=$((PASS + 1))
    return 0
  else
    echo "❌ FAIL ($http_code, invalid docs/domains structure)"
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

# Test Linear-lite API endpoints (all optional for now)
echo "=== Linear-lite API Endpoints (Optional) ==="

# Plan endpoint
test_endpoint "API Plan" "POST" "http://127.0.0.1:4000/api/plan" '{"goal":"test smoke check"}' "200" "true" || true

# Patch endpoint (dry-run)
test_endpoint "API Patch" "POST" "http://127.0.0.1:4000/api/patch" '{"dryRun":true}' "200" "true" || true

# Smoke endpoint
test_endpoint "API Smoke" "GET" "http://127.0.0.1:4000/api/smoke" "" "200" "true" || true

echo ""
echo "=== Paula Agent Smoke ==="

test_paula_crawl || true
test_paula_corpus_stats || true

echo ""

# Summary
echo "=== Smoke Test Summary ==="
echo "✅ PASS: $PASS"
echo "❌ FAIL: $FAIL" 
echo "⚠️  WARN: $WARN"
echo ""

append_paula_log

# Only fail if core services fail (API capabilities, UI)
if [ $FAIL -eq 0 ]; then
  echo "🎉 All critical tests passed!"
  exit 0
else
  echo "💥 Some tests failed. Check service status."
  exit 1
fi
