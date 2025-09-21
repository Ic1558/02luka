#!/bin/bash
# 02luka Agent Interface Setup Script
# Auto-populated by Codex during environment setup

set -e

echo "🚀 Setting up 02luka Agent Interface..."

# Environment detection
if command -v wrangler &> /dev/null; then
    echo "✅ Cloudflare Wrangler detected"
    HAS_CF=true
else
    echo "ℹ️  Cloudflare Wrangler not found (install with: npm i -g wrangler)"
    HAS_CF=false
fi

if command -v docker &> /dev/null; then
    echo "✅ Docker detected"
    HAS_DOCKER=true
else
    echo "⚠️  Docker not found - agent connections may not work"
    HAS_DOCKER=false
fi

# Check for 02luka system
if curl -s http://127.0.0.1:5012/health &> /dev/null; then
    echo "✅ 02luka MCP Gateway detected (port 5012)"
    HAS_02LUKA=true
else
    echo "ℹ️  02luka system not detected - UI will work but agents won't connect"
    HAS_02LUKA=false
fi

# Setup recommendations
echo ""
echo "📋 Setup Status:"
echo "  Cloudflare: ${HAS_CF:-false}"
echo "  Docker: ${HAS_DOCKER:-false}"
echo "  02luka System: ${HAS_02LUKA:-false}"
echo ""

if [ "$HAS_CF" = true ]; then
    echo "🌐 Ready for Cloudflare Pages deployment:"
    echo "  wrangler pages publish . --project-name=02luka-ui"
    echo ""
fi

if [ "$HAS_02LUKA" = true ]; then
    echo "🎯 Ready for local agent testing:"
    echo "  open luka_minimal.html"
    echo "  Select agents from dropdown and test connections"
    echo ""
fi

echo "✨ Setup complete! See README.md for next steps."