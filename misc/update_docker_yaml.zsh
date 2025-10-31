#!/usr/bin/env zsh
set -euo pipefail
BASE="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka"
YML="$BASE/docker-compose.yml"
BK="$BASE/docker-compose.yml.bak.$(date +%Y%m%d-%H%M%S)"
NET="02luka-net"
mkdir -p "$BASE"
[[ -f "$YML" ]] && cp "$YML" "$BK" || true
cat > "$YML" <<'COMPOSE'
version: '3.8'
networks:
  02luka-net: { external: true }
services:
  redis:
    image: redis:7-alpine
    container_name: redis
    command: ["redis-server","--appendonly","yes"]
    networks: { 02luka-net: { aliases: ["02luka-redis","redis"] } }
    volumes:
      - luka-ops_redis_data:/data:rw
  http_redis_bridge:
    image: 02luka-node-services:latest
    container_name: http_redis_bridge
    environment:
      - REDIS_URL=redis://02luka-redis:6379
      - BRIDGE_PORT=8788
    ports: ["8788:8788"]
    volumes:
      - /Users/icmini/LocalProjects/02luka_local_g/g:/app/g:rw
    networks: [02luka-net]
  clc_listener:
    image: 02luka-node-services:latest
    container_name: clc_listener
    environment:
      - REDIS_URL=redis://02luka-redis:6379
      - CLC_EXPORT_MODE_CHANNEL=gg:clc:export_mode
    networks: [02luka-net]
  ops_health_watcher:
    image: 02luka-node-services:latest
    container_name: ops_health_watcher
    environment:
      - OPS_HEALTH_URL=https://ops.theedges.work
    networks: [02luka-net]
volumes:
  luka-ops_redis_data: {}
COMPOSE
echo "✅ docker-compose.yml updated at $YML"
echo "Network: $NET"
echo "Service: redis, http_redis_bridge, clc_listener, ops_health_watcher"
