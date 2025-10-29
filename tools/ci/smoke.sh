#!/usr/bin/env bash
set -euo pipefail
echo "== OPS Phase 4 Smoke =="
# จุดประสงค์: ให้คอนเทนเนอร์ redis ของ CI ขึ้นและตอบสนอง
export REDIS_PASSWORD="${REDIS_PASSWORD:-changeme-02luka}"
docker compose -f docker/ci/docker-compose.ci.yml down -v >/dev/null 2>&1 || true
docker compose -f docker/ci/docker-compose.ci.yml up -d
echo "Waiting for redis..."
for i in {1..20}; do
  if docker compose -f docker/ci/docker-compose.ci.yml exec -T redis sh -lc \
     "redis-cli -a \"$REDIS_PASSWORD\" PING | grep -q PONG"; then
    echo "Redis ready"
    break
  fi
  sleep 1
done
docker compose -f docker/ci/docker-compose.ci.yml exec -T redis sh -lc \
  "redis-cli -a \"$REDIS_PASSWORD\" INFO server | head -n 5"
echo "SMOKE OK"
