#!/usr/bin/env bash
#
# Phase 4 Hardening Verification
# Comprehensive test suite for all Phase 4 components
#

set -euo pipefail

REPO="/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"
cd "$REPO"

TS=$(date +"%Y%m%d_%H%M")
REPORT_DIR="g/reports/phase4"
REPORT_FILE="$REPORT_DIR/verify_${TS}.md"

mkdir -p "$REPORT_DIR"

echo "=== Phase 4 Hardening Verification ===" | tee "$REPORT_FILE"
echo "Date: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

ALL_PASS=true

# Test results table
declare -a RESULTS

function test_file() {
  local name="$1"
  local file="$2"

  if [[ -f "$file" ]]; then
    RESULTS+=("| $name | PASS | File exists |")
    echo "✅ $name: exists" | tee -a "$REPORT_FILE"
    return 0
  else
    RESULTS+=("| $name | FAIL | File missing |")
    echo "❌ $name: missing" | tee -a "$REPORT_FILE"
    ALL_PASS=false
    return 1
  fi
}

function test_syntax() {
  local name="$1"
  local file="$2"
  local checker="$3"

  if $checker "$file" > /dev/null 2>&1; then
    RESULTS+=("| $name syntax | PASS | Valid syntax |")
    echo "✅ $name: syntax valid" | tee -a "$REPORT_FILE"
    return 0
  else
    RESULTS+=("| $name syntax | FAIL | Syntax error |")
    echo "❌ $name: syntax error" | tee -a "$REPORT_FILE"
    ALL_PASS=false
    return 1
  fi
}

echo "## 1. File Existence" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

test_file "Health Proxy" "gateway/health_proxy.js"
test_file "MCP WebBridge" "run/mcp_webbridge.cjs"
test_file "Boss API" "api/boss_api.cjs"
test_file "Health Proxy Wrapper" "run/wrappers/health_proxy.zsh"
test_file "MCP WebBridge Wrapper" "run/wrappers/mcp_webbridge.zsh"
test_file "Boss API Wrapper" "run/wrappers/boss_api.zsh"
test_file "Health Proxy Plist" "$HOME/Library/LaunchAgents/com.02luka.health.proxy.plist"
test_file "MCP WebBridge Plist" "$HOME/Library/LaunchAgents/com.02luka.mcp.webbridge.plist"
test_file "Boss API Plist" "$HOME/Library/LaunchAgents/com.02luka.boss.api.plist"
test_file "CI Workflow" ".github/workflows/ops_phase4.yml"

echo "" | tee -a "$REPORT_FILE"

echo "## 2. Syntax Validation" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

test_syntax "Health Proxy" "gateway/health_proxy.js" "node --check"
test_syntax "MCP WebBridge" "run/mcp_webbridge.cjs" "node --check"
test_syntax "Boss API" "api/boss_api.cjs" "node --check"
test_syntax "Health Proxy Plist" "$HOME/Library/LaunchAgents/com.02luka.health.proxy.plist" "plutil -lint"
test_syntax "MCP WebBridge Plist" "$HOME/Library/LaunchAgents/com.02luka.mcp.webbridge.plist" "plutil -lint"
test_syntax "Boss API Plist" "$HOME/Library/LaunchAgents/com.02luka.boss.api.plist" "plutil -lint"

echo "" | tee -a "$REPORT_FILE"

echo "## 3. Local Service Tests" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Test Health Proxy
echo "Testing Health Proxy (port 3002)..." | tee -a "$REPORT_FILE"
timeout 10 node gateway/health_proxy.js > /tmp/health_proxy_test.log 2>&1 &
HEALTH_PID=$!
sleep 3

if nc -z 127.0.0.1 3002 2>/dev/null; then
  echo "✅ Health Proxy: port open" | tee -a "$REPORT_FILE"
  RESULTS+=("| Health Proxy port check | PASS | Port 3002 listening |")

  if curl -sf http://127.0.0.1:3002/health > /dev/null; then
    echo "✅ Health Proxy: /health responds" | tee -a "$REPORT_FILE"
    RESULTS+=("| Health Proxy /health | PASS | Returns 200 |")
  else
    echo "❌ Health Proxy: /health failed" | tee -a "$REPORT_FILE"
    RESULTS+=("| Health Proxy /health | FAIL | No response |")
    ALL_PASS=false
  fi

  if curl -sf http://127.0.0.1:3002/metrics | grep -q "service_up"; then
    echo "✅ Health Proxy: /metrics valid" | tee -a "$REPORT_FILE"
    RESULTS+=("| Health Proxy /metrics | PASS | Prometheus format |")
  else
    echo "❌ Health Proxy: /metrics invalid" | tee -a "$REPORT_FILE"
    RESULTS+=("| Health Proxy /metrics | FAIL | Invalid format |")
    ALL_PASS=false
  fi
else
  echo "❌ Health Proxy: port not open" | tee -a "$REPORT_FILE"
  RESULTS+=("| Health Proxy port check | FAIL | Port not listening |")
  ALL_PASS=false
fi

kill $HEALTH_PID 2>/dev/null || true
sleep 1

# Test MCP WebBridge
echo "" | tee -a "$REPORT_FILE"
echo "Testing MCP WebBridge (port 3003)..." | tee -a "$REPORT_FILE"
timeout 10 node run/mcp_webbridge.cjs > /tmp/mcp_test.log 2>&1 &
MCP_PID=$!
sleep 3

if nc -z 127.0.0.1 3003 2>/dev/null; then
  echo "✅ MCP WebBridge: port open" | tee -a "$REPORT_FILE"
  RESULTS+=("| MCP WebBridge port check | PASS | Port 3003 listening |")

  if curl -sf http://127.0.0.1:3003/health > /dev/null; then
    echo "✅ MCP WebBridge: /health responds" | tee -a "$REPORT_FILE"
    RESULTS+=("| MCP WebBridge /health | PASS | Returns 200 |")
  else
    echo "❌ MCP WebBridge: /health failed" | tee -a "$REPORT_FILE"
    RESULTS+=("| MCP WebBridge /health | FAIL | No response |")
    ALL_PASS=false
  fi
else
  echo "❌ MCP WebBridge: port not open" | tee -a "$REPORT_FILE"
  RESULTS+=("| MCP WebBridge port check | FAIL | Port not listening |")
  ALL_PASS=false
fi

kill $MCP_PID 2>/dev/null || true
sleep 1

# Test Boss API
echo "" | tee -a "$REPORT_FILE"
echo "Testing Boss API (port 4000)..." | tee -a "$REPORT_FILE"
timeout 10 node api/boss_api.cjs > /tmp/boss_test.log 2>&1 &
BOSS_PID=$!
sleep 3

if nc -z 127.0.0.1 4000 2>/dev/null; then
  echo "✅ Boss API: port open" | tee -a "$REPORT_FILE"
  RESULTS+=("| Boss API port check | PASS | Port 4000 listening |")

  if curl -sf http://127.0.0.1:4000/healthz > /dev/null; then
    echo "✅ Boss API: /healthz responds" | tee -a "$REPORT_FILE"
    RESULTS+=("| Boss API /healthz | PASS | Returns 200 |")
  else
    echo "❌ Boss API: /healthz failed" | tee -a "$REPORT_FILE"
    RESULTS+=("| Boss API /healthz | FAIL | No response |")
    ALL_PASS=false
  fi
else
  echo "❌ Boss API: port not open" | tee -a "$REPORT_FILE"
  RESULTS+=("| Boss API port check | FAIL | Port not listening |")
  ALL_PASS=false
fi

kill $BOSS_PID 2>/dev/null || true
sleep 1

echo "" | tee -a "$REPORT_FILE"

# Write results table
echo "## Test Results Summary" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "| Test | Result | Details |" | tee -a "$REPORT_FILE"
echo "|------|--------|---------|" | tee -a "$REPORT_FILE"

for result in "${RESULTS[@]}"; do
  echo "$result" | tee -a "$REPORT_FILE"
done

echo "" | tee -a "$REPORT_FILE"

# Final verdict
if $ALL_PASS; then
  echo "## ✅ VERIFICATION PASSED" | tee -a "$REPORT_FILE"
  echo "" | tee -a "$REPORT_FILE"
  echo "All Phase 4 components are working correctly." | tee -a "$REPORT_FILE"
  echo "" | tee -a "$REPORT_FILE"
  echo "**Recommendations:**" | tee -a "$REPORT_FILE"
  echo "- Deploy LaunchAgents to production" | tee -a "$REPORT_FILE"
  echo "- Monitor services for 24 hours" | tee -a "$REPORT_FILE"
  echo "- Review auto-heal logs" | tee -a "$REPORT_FILE"
  exit 0
else
  echo "## ❌ VERIFICATION FAILED" | tee -a "$REPORT_FILE"
  echo "" | tee -a "$REPORT_FILE"
  echo "Some tests failed. Review errors above." | tee -a "$REPORT_FILE"
  echo "" | tee -a "$REPORT_FILE"
  echo "**Actions Required:**" | tee -a "$REPORT_FILE"
  echo "- Review test logs in /tmp/" | tee -a "$REPORT_FILE"
  echo "- Check service error logs" | tee -a "$REPORT_FILE"
  echo "- Re-run verification after fixes" | tee -a "$REPORT_FILE"
  exit 1
fi
