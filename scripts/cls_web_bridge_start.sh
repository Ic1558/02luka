#!/bin/bash
# Start CLS Web Bridge
# Phase 20 - CLS Web Bridge
# WO-ID: WO-251107-PHASE-20-CLS-WEB

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_SCRIPT="$PROJECT_DIR/tools/cls_web_bridge.cjs"
LOG_DIR="$PROJECT_DIR/g/logs"
PID_FILE="$PROJECT_DIR/g/metrics/cls_web_bridge.pid"

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
        echo "CLS Web Bridge is already running (PID: $PID)"
        exit 1
    else
        echo "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Start the service
echo "Starting CLS Web Bridge..."
echo "Logs: $LOG_DIR/cls_web_bridge.out.log"

nohup node "$SERVICE_SCRIPT" \
    > "$LOG_DIR/cls_web_bridge.out.log" \
    2> "$LOG_DIR/cls_web_bridge.err.log" &

echo $! > "$PID_FILE"

echo "CLS Web Bridge started (PID: $(cat $PID_FILE))"
echo "Service: http://127.0.0.1:8778"
echo "Health check: curl http://127.0.0.1:8778/health"

