#!/usr/bin/env bash
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 Ops Gate - Phase 5/6/7 Quality Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ ${cmd} not found"
    exit 1
  fi
}

echo "✅ Checking dependencies..."
check_cmd jq
check_cmd yq
echo "✅ Base dependencies present"

REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
# Leave empty by default; add -a only if provided
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

echo ""
echo "🧠 Checking Redis availability..."
if [[ "${OPS_GATE_OVERRIDE:-0}" == "1" ]]; then
  echo "⚠️  Gate override ON — skipping Redis connectivity check"
elif command -v redis-cli >/dev/null 2>&1; then
  redis_args=("-h" "$REDIS_HOST" "-p" "$REDIS_PORT")
  if [[ -n "$REDIS_PASSWORD" ]]; then
    redis_args+=("-a" "$REDIS_PASSWORD")
  fi
  if redis-cli "${redis_args[@]}" PING | grep -q PONG; then
    echo "✅ Redis responded to PING"
  else
    echo "❌ Redis PING failed"
    exit 1
  fi
else
  echo "⚠️  redis-cli not found, attempting TCP check via nc"
  if command -v nc >/dev/null 2>&1; then
    if timeout 3 nc -z "$REDIS_HOST" "$REDIS_PORT"; then
      echo "✅ Redis port reachable"
    else
      echo "❌ Unable to reach Redis port"
      exit 1
    fi
  else
    echo "⚠️  nc not available; skipping Redis connectivity check"
  fi
fi

echo ""
echo "📁 Creating required directories..."
mkdir -p g/memory g/reports g/telemetry

echo ""
echo "🔥 Running smoke tests..."
if [[ -x scripts/smoke_with_server.sh ]]; then
  bash scripts/smoke_with_server.sh
elif [[ -x scripts/smoke.sh ]]; then
  bash scripts/smoke.sh
else
  echo "⚠️  No smoke script found; skipping"
fi

echo ""
echo "🔍 Running self-review (non-blocking)..."
if command -v node >/dev/null 2>&1; then
  node agents/reflection/self_review.cjs --days=7 >/dev/null || echo "⚠️  self_review skipped (requires existing data)"
else
  echo "⚠️  Node.js not available; skipping self_review"
fi

echo ""
echo "✅ Ops gate checks complete"
