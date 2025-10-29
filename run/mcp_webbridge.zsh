#!/usr/bin/env zsh
set -euo pipefail
REPO="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"
LOG="$REPO/g/logs"
mkdir -p "$LOG"

log(){ print -P "$(date -u +%FT%TZ) [MCP] $*"; }
export PORT=3003

# Candidate commands in priority order (edit to match your repo)
candidates=(
  "node $REPO/run/mcp_webbridge.cjs"
  "node $REPO/run/mcp_bridge.cjs"
  "node $REPO/tools/mcp/webbridge.cjs"
  "tsx  $REPO/run/mcp_webbridge.ts"
  "python3 $REPO/run/mcp_webbridge.py"
  "docker compose -f $REPO/docker-compose.yml up mcp-bridge"
)

log "starting MCP WebBridge on port $PORT"
for cmd in "${candidates[@]}"; do
  if eval "command -v ${(z)cmd}[1]" >/dev/null 2>&1 || [[ "$cmd" == docker* ]]; then
    log "trying: $cmd"
    # If docker path, just run once and exit success (launchd keeps it alive)
    if [[ "$cmd" == docker* ]]; then
      eval "$cmd" && exit 0
    else
      exec $=cmd
    fi
  fi
done

log "ERROR: no viable start command found. Provide one of: run/mcp_webbridge.cjs|.ts|.py or docker service 'mcp-bridge'."
exit 127
