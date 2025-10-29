#!/usr/bin/env bash
set -euo pipefail

echo "🔎 MCP Health Check"

# Check MCP Docker container status (if Docker available)
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    CONTAINER_NAME="02luka-mcp"
    if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
      STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
      echo "• Docker container $CONTAINER_NAME: $STATUS"
    else
      echo "• Docker container 02luka-mcp: not found"
    fi
  else
    echo "• Docker is installed but not available"
  fi
else
  echo "• Docker not installed/available"
fi

# Check MCP FS (file system service) on default port 8765
MCP_FS_PORT=${MCP_FS_PORT:-8765}
if command -v nc >/dev/null 2>&1; then
  if nc -z localhost "$MCP_FS_PORT" >/dev/null 2>&1; then
    echo "• MCP FS on port $MCP_FS_PORT: online"
  else
    echo "• MCP FS on port $MCP_FS_PORT: offline"
  fi
else
  echo "• 'nc' (netcat) not available to probe MCP FS"
fi

exit 0

