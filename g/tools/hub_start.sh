#!/bin/bash
# Start Hub Dashboard Server
# Phase 20 - Hub Dashboard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HUB_SCRIPT="$PROJECT_DIR/tools/hub_server.cjs"
LOG_DIR="$PROJECT_DIR/g/logs"
PID_FILE="$PROJECT_DIR/g/metrics/hub.pid"

# Create directories
mkdir -p "$LOG_DIR" "$(dirname "$PID_FILE")"

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "Error: node not found"
    exit 1
fi

# Check if service is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Hub Dashboard is already running (PID: $PID)"
        echo "Dashboard: http://127.0.0.1:8787"
        exit 1
    else
        echo "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Start the service
echo "Starting Hub Dashboard..."
echo "Logs: $LOG_DIR/hub.out.log"

nohup node "$HUB_SCRIPT" \
    > "$LOG_DIR/hub.out.log" \
    2> "$LOG_DIR/hub.err.log" &

echo $! > "$PID_FILE"

echo "Hub Dashboard started (PID: $(cat "$PID_FILE"))"
echo "Dashboard: http://127.0.0.1:8787"
echo "SSE Stream: http://127.0.0.1:8787/hub/stream"

