#!/usr/bin/env zsh
set -euo pipefail
echo "🔧 Fix Dev Environment ($(date +'%F %T'))"

ensure_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "• Starting Docker Desktop..."
    open -a Docker || true
    # wait up to 90s
    for i in {1..90}; do
      docker info >/dev/null 2>&1 && break
      sleep 1
    done
  fi
  docker info >/dev/null 2>&1 || { echo "✖ Docker not ready"; exit 1; }
}

stack_up() {
  if [[ -f docker-compose.yml || -f compose.yml ]]; then
    echo "• Rebuilding stack…"
    docker compose down --remove-orphans || true
    docker compose pull || true
    docker compose up -d --remove-orphans
  else
    echo "• No docker compose found — skipping"
  fi
}

wait_ports() {
  ports=(${=1})
  for p in $ports; do
    printf "• Waiting port %s" "$p"
    for i in {1..30}; do
      if nc -z 127.0.0.1 "$p" 2>/dev/null; then echo " ...up"; break; fi
      printf "."; sleep 1
    done
    echo
  done
}

touch g/reports/system_health_stamp.txt 2>/dev/null || true
mkdir -p g/reports

ensure_docker
stack_up
wait_ports "6379 8788 3003 5012"

# Light checks
if nc -z 127.0.0.1 6379 2>/dev/null; then
  redis-cli -h 127.0.0.1 -p 6379 -a changeme-02luka ping >/dev/null 2>&1 || true
fi

date +"%F %T" > g/reports/system_health_stamp.txt
echo "✅ Fix complete."
