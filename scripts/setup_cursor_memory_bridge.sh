#!/usr/bin/env bash
# Setup and verify Cursor/Codex memory bridge
# Enables AI assistants in Cursor to access 02LUKA vector memory

set -euo pipefail

# Source universal path resolver
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/repo_root_resolver.sh"

echo "=== 02LUKA Memory Bridge Setup ==="
echo ""

# Step 1: Verify memory module exists
echo "1. Checking memory module..."
if [ ! -f "$REPO_ROOT/memory/index.cjs" ]; then
  echo "❌ Error: memory/index.cjs not found"
  exit 1
fi
echo "   ✅ Memory module found"

# Step 2: Verify memory index file
echo ""
echo "2. Checking memory index..."
if [ ! -f "$REPO_ROOT/g/memory/vector_index.json" ]; then
  echo "   ⚠️  No memory index yet (will be created on first use)"
else
  echo "   ✅ Memory index exists"
  # Show stats
  if command -v node >/dev/null 2>&1; then
    echo ""
    echo "   Memory Statistics:"
    node "$REPO_ROOT/memory/index.cjs" --stats | sed 's/^/   /'
  fi
fi

# Step 3: Test CLI access
echo ""
echo "3. Testing CLI access..."
if ! command -v node >/dev/null 2>&1; then
  echo "   ❌ Error: node is required but not found"
  exit 1
fi

# Test recall (might return empty if no memories yet)
echo "   Testing: node memory/index.cjs --recall 'test query'"
if node "$REPO_ROOT/memory/index.cjs" --recall "test query" >/dev/null 2>&1; then
  echo "   ✅ CLI access working"
else
  echo "   ❌ CLI access failed"
  exit 1
fi

# Step 4: Test API endpoints (if boss-api is running)
echo ""
echo "4. Testing API endpoints..."
API_BASE="http://127.0.0.1:4000"

if curl -f -s -m 2 "$API_BASE/healthz" >/dev/null 2>&1; then
  echo "   ✅ Boss API is running at $API_BASE"

  # Test memory stats endpoint
  echo "   Testing: GET /api/memory/stats"
  if curl -f -s -m 5 "$API_BASE/api/memory/stats" >/dev/null 2>&1; then
    echo "   ✅ Memory API endpoints working"
    echo ""
    echo "   API Endpoints Available:"
    echo "   - GET  $API_BASE/api/memory/recall?q=query[&kind=type][&topK=5]"
    echo "   - POST $API_BASE/api/memory/remember (JSON: {kind, text, meta})"
    echo "   - GET  $API_BASE/api/memory/stats"
  else
    echo "   ❌ Memory API endpoints not responding"
    exit 1
  fi
else
  echo "   ⚠️  Boss API not running (start with: cd boss-api && node server.cjs)"
  echo "   Memory will still work via CLI, but HTTP API will be unavailable"
fi

# Step 5: Verify Cursor context file
echo ""
echo "5. Checking Cursor context file..."
CURSOR_CONTEXT="$REPO_ROOT/.cursor/memory_context.md"
if [ -f "$CURSOR_CONTEXT" ]; then
  echo "   ✅ Cursor context file exists: .cursor/memory_context.md"
else
  echo "   ⚠️  Cursor context file not found"
  echo "   Creating .cursor/memory_context.md..."
  mkdir -p "$REPO_ROOT/.cursor"
  echo "# See docs/CONTEXT_ENGINEERING.md for memory system documentation" > "$CURSOR_CONTEXT"
  echo "   ✅ Created .cursor/memory_context.md"
fi

# Step 6: Create MCP server config (optional, for Claude Desktop)
echo ""
echo "6. MCP Server Configuration (Optional)..."
MCP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

if [ -f "$MCP_CONFIG" ]; then
  echo "   Found Claude Desktop config at: $MCP_CONFIG"
  echo ""
  echo "   To enable memory access in Claude Desktop, add this to mcpServers:"
  echo ""
  cat <<'EOF'
  "02luka-memory": {
    "command": "node",
    "args": ["$REPO_ROOT/memory/index.cjs", "--mcp-server"],
    "env": {
      "REPO_ROOT": "$REPO_ROOT"
    }
  }
EOF
  echo ""
  echo "   (Replace $REPO_ROOT with actual path: $REPO_ROOT)"
else
  echo "   ⚠️  Claude Desktop config not found (skip if not using Claude Desktop)"
fi

# Step 7: Usage examples
echo ""
echo "=== Setup Complete ==="
echo ""
echo "How to use memory in Cursor/Codex:"
echo ""
echo "Option 1: CLI Access (Always Available)"
echo "  node memory/index.cjs --recall 'your query'"
echo "  node memory/index.cjs --recall-kind solution 'macOS issues'"
echo "  node memory/index.cjs --stats"
echo ""
echo "Option 2: HTTP API (When boss-api is running)"
echo "  curl 'http://127.0.0.1:4000/api/memory/recall?q=Discord+integration'"
echo "  curl 'http://127.0.0.1:4000/api/memory/stats'"
echo ""
echo "Option 3: Direct File Access"
echo "  Read: g/memory/vector_index.json"
echo "  Context: .cursor/memory_context.md"
echo ""
echo "Integration with AI Assistants:"
echo "  1. Reference .cursor/memory_context.md in your Cursor prompts"
echo "  2. Ask AI to query memory before solving problems"
echo "  3. Suggest recording solutions after successful implementations"
echo ""
echo "Documentation: docs/CONTEXT_ENGINEERING.md (Vector Memory System section)"
echo ""
