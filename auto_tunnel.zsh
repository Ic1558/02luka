#!/bin/zsh
# 02luka Auto Tunnel & Config Updater
# เปิด tunnel อัตโนมัติและอัพเดท config ใน UI

echo "🚀 02LUKA AUTO TUNNEL LAUNCHER"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check dependencies
check_deps() {
    local missing=()

    if ! command -v ngrok &> /dev/null; then
        missing+=("ngrok")
    fi

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo "⚠️  Missing dependencies: ${missing[@]}"
        echo ""
        echo "Installing via Homebrew..."
        for dep in "${missing[@]}"; do
            brew install $dep
        done
        echo ""
    fi
}

# Kill existing tunnels
cleanup() {
    echo "🧹 Cleaning up existing tunnels..."
    pkill -f ngrok 2>/dev/null
    pkill -f cloudflared 2>/dev/null
    rm -f /tmp/tunnel_*.json 2>/dev/null
}

# Start ngrok tunnel
start_ngrok_tunnel() {
    local port=$1
    local name=$2

    echo "🔗 Starting ngrok tunnel for $name (port $port)..."

    # Start ngrok in background
    ngrok http $port --log-format=json --log=/tmp/ngrok_${name}.log > /dev/null 2>&1 &
    local pid=$!
    echo $pid > /tmp/ngrok_${name}.pid

    # Wait for tunnel to establish
    echo -n "   Waiting for tunnel"
    for i in {1..10}; do
        sleep 1
        echo -n "."

        # Check ngrok API
        local url=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null)

        if [ ! -z "$url" ] && [ "$url" != "null" ]; then
            echo ""
            echo "   ✅ Tunnel established: ${GREEN}$url${NC}"
            echo "$url" > /tmp/tunnel_${name}.url
            return 0
        fi
    done

    echo ""
    echo "   ❌ Failed to establish tunnel"
    return 1
}

# Update HTML with new URLs
update_ui_config() {
    local mcp_url=$1
    local fs_url=$2
    local ollama_url=$3

    echo ""
    echo "📝 Updating UI configuration..."

    # Backup current luka.html
    cp luka.html luka.html.backup.$(date +%s)

    # Create updated gateway config
    cat > /tmp/gateway_config.js << EOF
// Auto-generated gateway config $(date)
const GATEWAY_CONFIG = {
    mcp_docker: '${mcp_url:-http://127.0.0.1:5012}',
    mcp_fs: '${fs_url:-http://127.0.0.1:8765}',
    ollama: '${ollama_url:-http://localhost:11434}'
};

// Update dropdown options
document.addEventListener('DOMContentLoaded', () => {
    const gatewaySelect = document.getElementById('gateway');
    if (gatewaySelect) {
        gatewaySelect.innerHTML = \`
            <option value="\${GATEWAY_CONFIG.mcp_docker}">MCP Docker (Tunnel)</option>
            <option value="\${GATEWAY_CONFIG.mcp_fs}">MCP FS (Tunnel)</option>
            <option value="\${GATEWAY_CONFIG.ollama}">Ollama (Tunnel)</option>
            <option value="http://127.0.0.1:5012">MCP Docker (Local)</option>
            <option value="http://127.0.0.1:8765">MCP FS (Local)</option>
            <option value="http://localhost:11434">Ollama (Local)</option>
        \`;
    }
});
EOF

    # Inject config into HTML
    if grep -q "GATEWAY_CONFIG" luka.html; then
        echo "   Config already exists, updating..."
        # Update existing config
        perl -i -pe 's|const GATEWAY_CONFIG = \{[^}]+\}|'"$(cat /tmp/gateway_config.js | grep 'const GATEWAY_CONFIG')"'|' luka.html
    else
        echo "   Injecting new config..."
        # Add config before closing </head>
        perl -i -pe 's|</head>|<script>\n'"$(cat /tmp/gateway_config.js)"'\n</script>\n</head>|' luka.html
    fi

    echo "   ✅ UI configuration updated"
}

# Main execution
main() {
    echo "${BLUE}Starting 02luka tunnel system...${NC}"
    echo ""

    # Check dependencies
    check_deps

    # Clean up existing tunnels
    cleanup

    # Check which services are running
    echo "🔍 Checking local services..."

    local services_to_tunnel=()
    local tunnel_urls=()

    # Check MCP Docker
    if curl -s http://127.0.0.1:5012/health > /dev/null 2>&1; then
        echo "   ✅ MCP Docker (5012) is running"
        services_to_tunnel+=("5012:mcp_docker")
    else
        echo "   ⚠️  MCP Docker (5012) not running"
    fi

    # Check MCP FS
    if lsof -iTCP:8765 -sTCP:LISTEN > /dev/null 2>&1; then
        echo "   ✅ MCP FS (8765) is running"
        services_to_tunnel+=("8765:mcp_fs")
    else
        echo "   ⚠️  MCP FS (8765) not running"
    fi

    # Check Ollama
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "   ✅ Ollama (11434) is running"
        services_to_tunnel+=("11434:ollama")
    else
        echo "   ⚠️  Ollama (11434) not running"
    fi

    echo ""

    # Start tunnels for running services
    if [ ${#services_to_tunnel[@]} -eq 0 ]; then
        echo "❌ No services running to tunnel!"
        echo "   Start services first:"
        echo "   • MCP Docker: docker start 02luka-mcp"
        echo "   • MCP FS: ~/.local/bin/mcp_fs"
        echo "   • Ollama: ollama serve"
        exit 1
    fi

    echo "🚇 Creating tunnels for ${#services_to_tunnel[@]} service(s)..."
    echo ""

    # Create tunnels
    local mcp_url=""
    local fs_url=""
    local ollama_url=""

    for service in "${services_to_tunnel[@]}"; do
        IFS=':' read -r port name <<< "$service"

        if start_ngrok_tunnel $port $name; then
            url=$(cat /tmp/tunnel_${name}.url)

            case $name in
                mcp_docker) mcp_url=$url ;;
                mcp_fs) fs_url=$url ;;
                ollama) ollama_url=$url ;;
            esac

            tunnel_urls+=("$name=$url")
        fi
    done

    # Update UI config
    update_ui_config "$mcp_url" "$fs_url" "$ollama_url"

    # Commit changes
    echo ""
    echo "💾 Saving configuration..."
    git add luka.html
    git commit -m "auto: update gateway URLs to tunnels $(date +%Y%m%d_%H%M%S)" 2>/dev/null
    git push origin main 2>/dev/null

    # Summary
    echo ""
    echo "========================================="
    echo "${GREEN}✅ TUNNELS ACTIVE!${NC}"
    echo ""
    echo "🌐 Public URLs:"
    for url_pair in "${tunnel_urls[@]}"; do
        IFS='=' read -r name url <<< "$url_pair"
        echo "   ${BLUE}$name${NC}: $url"
    done
    echo ""
    echo "📱 Access UI at:"
    echo "   • GitHub Pages: ${GREEN}https://ic1558.github.io/02luka/${NC}"
    echo "   • Local: ${GREEN}http://localhost:8080${NC} (run ./run_local.sh)"
    echo ""
    echo "📊 Monitor tunnels: http://localhost:4040"
    echo ""
    echo "⚠️  Keep this terminal open! Press Ctrl+C to stop tunnels."
    echo "========================================="

    # Keep running
    trap "cleanup; echo 'Tunnels stopped.'; exit" INT TERM

    while true; do
        sleep 60
        # Health check
        for url_pair in "${tunnel_urls[@]}"; do
            IFS='=' read -r name url <<< "$url_pair"
            if ! curl -s "$url" > /dev/null 2>&1; then
                echo "⚠️  Tunnel $name seems down, checking..."
            fi
        done
    done
}

# Run
main "$@"