#!/usr/bin/env zsh
set -euo pipefail

SERVICE="health_proxy"
PORT=3002
SCRIPT="gateway/health_proxy.js"
REPO="/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"

cd "$REPO"

while true; do
  echo "[$(date)] Starting $SERVICE on port $PORT" | tee -a g/logs/${SERVICE}_wrapper.log

  if /opt/homebrew/bin/node "$SCRIPT"; then
    echo "[$(date)] $SERVICE exited cleanly" | tee -a g/logs/${SERVICE}_wrapper.log
  else
    EXIT_CODE=$?
    echo "[$(date)] $SERVICE crashed with exit code $EXIT_CODE" | tee -a g/logs/${SERVICE}_wrapper.log
  fi

  echo "[$(date)] Waiting 300s before restart..." | tee -a g/logs/${SERVICE}_wrapper.log
  sleep 300
done
