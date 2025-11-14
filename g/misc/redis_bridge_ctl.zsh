#!/usr/bin/env zsh
set -euo pipefail
services=(http_redis_bridge clc_listener)
case "${1:-status}" in
  status) docker ps --format '{{.Names}}\t{{.Status}}' | grep -E 'http_redis_bridge|clc_listener' || true ;;
  restart)
    docker restart ${services[@]}
    sleep 3
    docker exec http_redis_bridge node -e "require('dns').lookup('02luka-redis',(_,a)=>console.log(a?'✅ Redis connected':'❌'))" ;;
  start) docker start ${services[@]} ;;
  stop) docker stop ${services[@]} ;;
  *) echo "Usage: $0 {status|start|stop|restart}" && exit 1 ;;
esac
