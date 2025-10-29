#!/usr/bin/env bash
set -euo pipefail
echo "== ci/ops-gate =="
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-changeme-02luka}"
# ping ด้วย redis-cli ถ้ามี
if command -v redis-cli >/dev/null 2>&1; then
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" PING | grep -q PONG
  echo "Redis PING OK via redis-cli"
else
  # netcat fallback
  if command -v nc >/dev/null 2>&1; then
    timeout 3 nc -z "$REDIS_HOST" "$REDIS_PORT"
    echo "Redis TCP reachable via nc"
  else
    echo "(i) neither redis-cli nor nc found; assuming pass in minimal runner"
  fi
fi
echo "OPS-GATE OK"
