#!/bin/bash
# Stop Hub Dashboard Server
# Phase 20 - Hub Dashboard

set -euo pipefail

PROJECT_DIR="${HOME}/02luka"
PID_FILE="$PROJECT_DIR/g/metrics/hub.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "Hub Dashboard is not running (no PID file)"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "Hub Dashboard is not running (stale PID file)"
    rm -f "$PID_FILE"
    exit 1
fi

echo "Stopping Hub Dashboard (PID: $PID)..."
kill "$PID" || true

# Wait for process to stop
sleep 2

if ps -p "$PID" > /dev/null 2>&1; then
    echo "Force killing..."
    kill -9 "$PID" || true
fi

rm -f "$PID_FILE"
echo "Hub Dashboard stopped"

