#!/bin/bash
# Start FAISS Vector Service
# Phase 15 - FAISS/HNSW Integration
# WO-ID: WO-251107-PHASE-15-FAISS-HNSW

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_SCRIPT="$PROJECT_DIR/run/faiss_vector_service.py"
LOG_DIR="$PROJECT_DIR/g/logs"
PID_FILE="$PROJECT_DIR/run/faiss_vector_service.pid"

# Create log directory
mkdir -p "$LOG_DIR"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found"
    exit 1
fi

# Check if service is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "FAISS Vector Service is already running (PID: $PID)"
        exit 1
    else
        echo "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Install dependencies if needed
if ! python3 -c "import faiss" 2>/dev/null; then
    echo "Installing Python dependencies..."
    python3 -m pip install -q -r "$PROJECT_DIR/requirements.txt"
fi

# Check for OpenAI API key
if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "Warning: OPENAI_API_KEY not set. Set it in environment or .env file"
    if [ -f "$PROJECT_DIR/.env" ]; then
        export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
    fi
fi

# Start the service
echo "Starting FAISS Vector Service..."
echo "Logs: $LOG_DIR/faiss_vector_service.out.log"

nohup python3 "$SERVICE_SCRIPT" \
    > "$LOG_DIR/faiss_vector_service.out.log" \
    2> "$LOG_DIR/faiss_vector_service.err.log" &

echo $! > "$PID_FILE"

echo "FAISS Vector Service started (PID: $(cat $PID_FILE))"
echo "Service: http://127.0.0.1:8766"
echo "Health check: curl http://127.0.0.1:8766/health"
