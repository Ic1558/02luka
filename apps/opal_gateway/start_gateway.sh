#!/bin/bash
# 02luka Opal Gateway Startup Script
# Run this to start the gateway server

cd ~/02luka/apps/opal_gateway || exit 1

echo "🚀 Starting 02luka Opal Gateway..."
echo "   Bridge Inbox: ~/02luka/bridge/inbox/LIAM"
echo "   Server: http://localhost:5000"
echo ""
echo "Available endpoints:"
echo "   GET  /           - Health check"
echo "   GET  /ping       - Quick ping"
echo "   POST /api/wo     - Receive Work Orders from Opal"
echo "   GET  /stats      - Gateway statistics"
echo ""
echo "Press Ctrl+C to stop"
echo "=========================================="
echo ""

# Check if virtual environment exists
if [ ! -d .venv ]; then
    echo "⚠️  Virtual environment not found. Creating..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
else
    source .venv/bin/activate
fi

# Run the gateway
python gateway.py
