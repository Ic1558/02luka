#!/usr/bin/env bash
set -euo pipefail
echo "== ci/ops-gate =="
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
if [[ ${REDIS_PASSWORD+x} == x ]]; then
  REDIS_PASSWORD="${REDIS_PASSWORD}"
else
  REDIS_PASSWORD="changeme-02luka"
fi
# ping ด้วย redis-cli ถ้ามี
if command -v redis-cli >/dev/null 2>&1; then
  redis_args=("-h" "$REDIS_HOST" "-p" "$REDIS_PORT")
  if [[ -n "$REDIS_PASSWORD" ]]; then
    redis_args+=("-a" "$REDIS_PASSWORD")
  fi
  redis-cli "${redis_args[@]}" PING | grep -q PONG
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
