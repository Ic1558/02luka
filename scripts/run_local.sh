#!/bin/bash
# 02luka Local Development Server
# Runs the UI locally so it can connect to local gateways

echo "🚀 Starting 02luka Local Server..."
echo ""
echo "📍 Local gateways available:"
echo "   • MCP Docker: http://127.0.0.1:5012"
echo "   • MCP FS: http://127.0.0.1:8765"
echo "   • Ollama: http://localhost:11434"
echo ""

# Check if Python 3 is available
if command -v python3 &> /dev/null; then
    echo "✅ Using Python 3 HTTP server on port 8080..."
    echo ""
    echo "🌐 Open in browser: http://localhost:8080"
    echo "   or: http://127.0.0.1:8080"
    echo ""
    echo "📝 Press Ctrl+C to stop the server"
    echo ""
    python3 -m http.server 8080
elif command -v python &> /dev/null; then
    echo "✅ Using Python 2 HTTP server on port 8080..."
    echo ""
    echo "🌐 Open in browser: http://localhost:8080"
    echo "   or: http://127.0.0.1:8080"
    echo ""
    echo "📝 Press Ctrl+C to stop the server"
    echo ""
    python -m SimpleHTTPServer 8080
else
    echo "❌ Python not found. Please install Python to run the local server."
    echo "   Alternative: Open luka.html directly in your browser (file://)"
    exit 1
fi