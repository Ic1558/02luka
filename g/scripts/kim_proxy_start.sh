#!/bin/bash
# Start Kim Proxy Gateway
# Phase 15 - Autonomous Knowledge Routing (AKR)
# WO-ID: WO-251107-PHASE-15-KIM-PROXY

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_SCRIPT="$PROJECT_DIR/run/kim_proxy_gateway.cjs"
LOG_DIR="$PROJECT_DIR/g/logs"
PID_FILE="$PROJECT_DIR/run/kim_proxy_gateway.pid"

# Create log directory
mkdir -p "$LOG_DIR"

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "Error: node not found"
    exit 1
fi

# Check if service is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Kim Proxy Gateway is already running (PID: $PID)"
        exit 1
    else
        echo "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Start the service
echo "Starting Kim Proxy Gateway..."
echo "Logs: $LOG_DIR/kim_proxy_gateway.out.log"

nohup node "$SERVICE_SCRIPT" \
    > "$LOG_DIR/kim_proxy_gateway.out.log" \
    2> "$LOG_DIR/kim_proxy_gateway.err.log" &

echo $! > "$PID_FILE"

echo "Kim Proxy Gateway started (PID: $(cat $PID_FILE))"
echo "Service: http://127.0.0.1:8767"
echo "Health check: curl http://127.0.0.1:8767/health"
