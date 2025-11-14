#!/usr/bin/env zsh
# Kim K2 Integration Test Runner
# Tests the full integration flow: Redis → Dispatcher → Profile Store
# This is a REAL tool that provides REAL value - validates end-to-end flow!

set -euo pipefail

REPO="$HOME/02luka"
LOG="$REPO/logs/kim_integration_test.log"

mkdir -p "$(dirname "$LOG")"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

echo "$(ts) Starting Kim K2 integration tests..." | tee -a "$LOG"

# Check prerequisites
echo "🔍 Checking prerequisites..." | tee -a "$LOG"

# 1. Check Redis connectivity
if command -v redis-cli &>/dev/null; then
  HOST="${REDIS_HOST:-127.0.0.1}"
  PORT="${REDIS_PORT:-6379}"
  PASSWORD="${REDIS_PASSWORD:-}"
  
  args=( -h "$HOST" -p "$PORT" )
  [[ -n "$PASSWORD" ]] && args+=( -a "$PASSWORD" )
  
  if redis-cli "${args[@]}" PING >/dev/null 2>&1; then
    echo "  ✅ Redis reachable" | tee -a "$LOG"
  else
    echo "  ⚠️  Redis not reachable (tests may fail)" | tee -a "$LOG"
  fi
else
  echo "  ⚠️  redis-cli not found (skipping Redis check)" | tee -a "$LOG"
fi

# 2. Check dispatcher process
if pgrep -f "nlp_command_dispatcher.py" >/dev/null 2>&1; then
  echo "  ✅ Dispatcher running" | tee -a "$LOG"
else
  echo "  ⚠️  Dispatcher not running (tests may fail)" | tee -a "$LOG"
fi

# 3. Run integration tests
echo "🧪 Running integration tests..." | tee -a "$LOG"

INTEGRATION_TEST="$REPO/tests/integration/test_kim_k2_flow.py"

if [[ ! -f "$INTEGRATION_TEST" ]]; then
  echo "❌ Integration test file not found: $INTEGRATION_TEST" | tee -a "$LOG"
  exit 1
fi

if ! command -v pytest &>/dev/null; then
  echo "❌ pytest not found. Install with: pip install pytest" | tee -a "$LOG"
  exit 1
fi

if pytest -v "$INTEGRATION_TEST" >> "$LOG" 2>&1; then
  echo "  ✅ Integration tests passed" | tee -a "$LOG"
  echo "$(ts) Integration tests completed successfully" | tee -a "$LOG"
  echo ""
  echo "✅ Integration tests passed!"
  echo "   This tool validates the full flow works - REAL value!"
  exit 0
else
  echo "  ❌ Integration tests failed" | tee -a "$LOG"
  echo "$(ts) Integration tests completed with failures" | tee -a "$LOG"
  echo ""
  echo "❌ Integration tests failed. Check $LOG for details."
  exit 1
fi
