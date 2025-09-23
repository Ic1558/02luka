#!/bin/bash
# Expose 02luka gateways to the internet using Cloudflare Tunnel
# This allows GitHub Pages UI to connect to your local services

echo "🌐 02luka Gateway Exposer"
echo "========================="
echo ""

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "⚠️  cloudflared not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install cloudflared
    else
        echo "Please install cloudflared: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation"
        exit 1
    fi
fi

# Function to run tunnel in background
expose_service() {
    local port=$1
    local name=$2
    echo "🔗 Exposing $name on port $port..."
    cloudflared tunnel --url http://localhost:$port > /tmp/cf_$name.log 2>&1 &
    local pid=$!
    echo $pid > /tmp/cf_$name.pid

    # Wait for URL
    echo "   Waiting for tunnel URL..."
    sleep 5
    grep -o 'https://.*\.trycloudflare.com' /tmp/cf_$name.log | head -1
}

# Start tunnels
echo "Starting Cloudflare tunnels for 02luka gateways..."
echo ""

# MCP Docker Gateway
MCP_URL=$(expose_service 5012 mcp_docker)
echo "✅ MCP Docker: $MCP_URL"
echo ""

# MCP FS Gateway
FS_URL=$(expose_service 8765 mcp_fs)
echo "✅ MCP FS: $FS_URL"
echo ""

# Ollama (optional)
read -p "Expose Ollama too? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    OLLAMA_URL=$(expose_service 11434 ollama)
    echo "✅ Ollama: $OLLAMA_URL"
    echo ""
fi

echo "================================"
echo "🎉 Gateways exposed!"
echo ""
echo "Update your UI gateway dropdown with these URLs:"
echo "  MCP Docker: $MCP_URL"
echo "  MCP FS: $FS_URL"
[[ ! -z "$OLLAMA_URL" ]] && echo "  Ollama: $OLLAMA_URL"
echo ""
echo "⚠️  Remember to add CORS headers to your services:"
echo '  Access-Control-Allow-Origin: https://ic1558.github.io'
echo '  Access-Control-Allow-Methods: GET, POST, OPTIONS'
echo '  Access-Control-Allow-Headers: Content-Type'
echo ""
echo "Press Ctrl+C to stop all tunnels"
echo ""

# Keep running
trap "pkill -f cloudflared; echo 'Tunnels stopped.'" EXIT
wait