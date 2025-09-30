#!/bin/bash
# 02luka System Verification & Debug Script
# Checks deployment, services, and provides optimization report

echo "🔍 02LUKA SYSTEM VERIFICATION"
echo "=============================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. DEPLOYMENT CHECK
echo "📦 1. DEPLOYMENT STATUS"
echo "-----------------------"
DEPLOY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://ic1558.github.io/02luka/")
if [ "$DEPLOY_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ GitHub Pages: LIVE${NC}"
    echo "   URL: https://ic1558.github.io/02luka/"

    # Check file size
    SIZE=$(curl -s "https://ic1558.github.io/02luka/" | wc -c)
    echo "   Size: $((SIZE/1024))KB"
else
    echo -e "${RED}❌ GitHub Pages: DOWN (HTTP $DEPLOY_STATUS)${NC}"
fi
echo ""

# 2. LOCAL SERVICES CHECK
echo "🖥️  2. LOCAL SERVICES"
echo "-------------------"

# MCP Docker
if curl -s http://127.0.0.1:5012/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ MCP Docker (5012): HEALTHY${NC}"
    HEALTH=$(curl -s http://127.0.0.1:5012/health | jq -r .status 2>/dev/null || echo "unknown")
    echo "   Status: $HEALTH"
else
    echo -e "${RED}❌ MCP Docker (5012): OFFLINE${NC}"
fi

# MCP FS
if lsof -iTCP:8765 -sTCP:LISTEN > /dev/null 2>&1; then
    echo -e "${GREEN}✅ MCP FS (8765): LISTENING${NC}"
else
    echo -e "${YELLOW}⚠️  MCP FS (8765): NOT RUNNING${NC}"
fi

# Ollama
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ollama (11434): ACTIVE${NC}"
    MODELS=$(curl -s http://localhost:11434/api/tags | jq -r '.models | length' 2>/dev/null || echo "0")
    echo "   Models loaded: $MODELS"
else
    echo -e "${YELLOW}⚠️  Ollama (11434): OFFLINE${NC}"
fi
echo ""

# 3. DOCKER STATUS
echo "🐳 3. DOCKER CONTAINERS"
echo "---------------------"
if command -v docker &> /dev/null; then
    RUNNING=$(/Applications/Docker.app/Contents/Resources/bin/docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    echo "   Running containers: $RUNNING"

    # List 02luka related containers
    /Applications/Docker.app/Contents/Resources/bin/docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep -E "mary|lisa|kim|mcp|02luka" || echo "   No 02luka containers found"
else
    echo -e "${YELLOW}⚠️  Docker not available${NC}"
fi
echo ""

# 4. NETWORK DIAGNOSTICS
echo "🌐 4. NETWORK DIAGNOSTICS"
echo "------------------------"
echo "Local endpoints accessible from browser:"
if [ -f "luka.html" ]; then
    echo -e "${GREEN}✅ luka.html exists ($(wc -l < luka.html) lines)${NC}"

    # Check for common issues
    if grep -q "getElementById.*input" luka.html && grep -q "getElementById.*send" luka.html; then
        echo -e "${GREEN}✅ UI elements properly defined${NC}"
    else
        echo -e "${YELLOW}⚠️  UI elements may have issues${NC}"
    fi
else
    echo -e "${RED}❌ luka.html not found${NC}"
fi
echo ""

# 5. OPTIMIZATION REPORT
echo "⚡ 5. OPTIMIZATION SUGGESTIONS"
echo "-----------------------------"

ISSUES=0

# Check if services are running
if ! curl -s http://127.0.0.1:5012/health > /dev/null 2>&1; then
    echo "• Start MCP Docker: docker start 02luka-mcp"
    ((ISSUES++))
fi

if ! lsof -iTCP:8765 -sTCP:LISTEN > /dev/null 2>&1; then
    echo "• Start MCP FS: ~/.local/bin/mcp_fs"
    ((ISSUES++))
fi

# Check file size
if [ -f "luka.html" ]; then
    HTML_SIZE=$(wc -c < luka.html)
    if [ $HTML_SIZE -gt 50000 ]; then
        echo "• HTML file large (${HTML_SIZE} bytes) - consider minification"
        ((ISSUES++))
    fi
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ System optimized and ready!${NC}"
else
    echo -e "${YELLOW}Found $ISSUES optimization opportunities${NC}"
fi
echo ""

# 6. QUICK ACTIONS
echo "🚀 6. QUICK ACTIONS"
echo "------------------"
echo "• Run locally:     ./run_local.sh"
echo "• Expose to web:   ./expose_gateways.sh"
echo "• View on GitHub:  open https://ic1558.github.io/02luka/"
echo "• Check logs:      tail -f /tmp/docker-autohealing.log"
echo ""

# 7. SYSTEM SUMMARY
echo "📊 SUMMARY"
echo "----------"
TOTAL_CHECKS=5
PASSED=0

[ "$DEPLOY_STATUS" = "200" ] && ((PASSED++))
curl -s http://127.0.0.1:5012/health > /dev/null 2>&1 && ((PASSED++))
lsof -iTCP:8765 -sTCP:LISTEN > /dev/null 2>&1 && ((PASSED++))
curl -s http://localhost:11434/api/tags > /dev/null 2>&1 && ((PASSED++))
[ -f "luka.html" ] && ((PASSED++))

PERCENT=$((PASSED * 100 / TOTAL_CHECKS))

if [ $PERCENT -ge 80 ]; then
    echo -e "${GREEN}System Health: $PERCENT% ($PASSED/$TOTAL_CHECKS checks passed)${NC}"
elif [ $PERCENT -ge 60 ]; then
    echo -e "${YELLOW}System Health: $PERCENT% ($PASSED/$TOTAL_CHECKS checks passed)${NC}"
else
    echo -e "${RED}System Health: $PERCENT% ($PASSED/$TOTAL_CHECKS checks passed)${NC}"
fi

echo ""
echo "Verification complete at $(date '+%Y-%m-%d %H:%M:%S')"