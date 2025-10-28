#!/usr/bin/env zsh
set -euo pipefail
c_ok(){ print -P "%F{green}OK%f  $1" }
c_warn(){ print -P "%F{yellow}WARN%f $1" }
c_bad(){ print -P "%F{red}FAIL%f $1" }

echo "🔎 Quick Diagnostic ($(date +'%F %T'))"

# Docker
if pgrep -xq Docker || docker info >/dev/null 2>&1; then
  c_ok "Docker running"
else
  c_bad "Docker not running (open -a Docker)"
fi

# Containers (summary)
if command -v docker >/dev/null 2>&1; then
  RUN=$(docker ps -q | wc -l | tr -d ' ')
  ALL=$(docker ps -aq | wc -l | tr -d ' ')
  echo "   Containers: $RUN/$ALL running"
fi

# Redis
if nc -z 127.0.0.1 6379 2>/dev/null; then
  RESP=$( (redis-cli -h 127.0.0.1 -p 6379 -a changeme-02luka ping) 2>/dev/null || true )
  [[ "$RESP" = "PONG" ]] && c_ok "Redis (6379) PONG" || c_warn "Redis reachable but auth failed"
else
  c_bad "Redis (6379) not reachable"
fi

# Bridges/Services
for svc in "MCP Bridge:3003" "HTTP Bridge:8788" "FastVLM:5012" ; do
  name=${svc%%:*}; port=${svc##*:}
  if nc -z 127.0.0.1 "$port" 2>/dev/null; then c_ok "$name ($port) open"; else c_warn "$name ($port) closed"; fi
done

# LaunchAgents (macOS only)
if [[ "$OSTYPE" == darwin* ]]; then
  FAILS=$(launchctl list | awk 'NR>1 && $3 ~ /^com\.02luka\./ && $2!~/^\-$/ && $2!=0' | wc -l | tr -d ' ')
  TOTAL=$(launchctl list | awk 'NR>1 && $3 ~ /^com\.02luka\./' | wc -l | tr -d ' ')
  echo "   LaunchAgents com.02luka.* : $((TOTAL-FAILS))/$TOTAL healthy, $FAILS failed"
fi

# System health stamp
STAMP="g/reports/system_health_stamp.txt"
mkdir -p g/reports
if [[ -f "$STAMP" ]]; then
  AGE=$(( $(date +%s) - $(stat -f %m "$STAMP" 2>/dev/null || stat -c %Y "$STAMP") ))
  echo "   System health age: ${AGE}s"
else
  echo "   System health stamp: missing"
fi
