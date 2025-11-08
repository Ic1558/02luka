#!/usr/bin/env zsh
set -euo pipefail
echo "🔍 Scanning MCP servers..."
node hub/mcp_discovery.mjs
git add hub/mcp_registry.json
git commit -m "chore(mcp): manual MCP scan update" || echo "No changes"
git push
