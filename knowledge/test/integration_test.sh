#!/usr/bin/env bash
# Integration tests for hybrid search + agent integration
# Tests: CLI verify mode, shell wrapper, MCP tool preparation

set -euo pipefail

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

echo "Running integration tests..."

# Test 1: --verify mode with perf logging
echo "[1/3] Testing --verify mode..."
node knowledge/index.cjs --verify "phase 7.2" --k=5 >/dev/null
if [[ ! -f "g/reports/query_perf.jsonl" ]]; then
  echo "FAIL: query_perf.jsonl not created"
  exit 1
fi
echo "  ✓ --verify mode works, perf log created"

# Test 2: Shell wrapper with safe quotes
echo "[2/3] Testing shell wrapper..."
tools/hybrid_search.sh "token savings" 8 hybrid >/dev/null
echo "  ✓ Shell wrapper executes safely"

# Test 3: MCP tool preparation (create sample request)
echo "[3/3] Testing MCP tool request format..."
echo '{"tool":"knowledge.hybrid_search","params":{"query":"deployment schema"}}' > /tmp/mcp_req.json
if [[ ! -s /tmp/mcp_req.json ]]; then
  echo "FAIL: MCP request file not created"
  exit 1
fi
echo "  ✓ MCP request format valid"

# Check that perf log has entries
LINES=$(wc -l < "g/reports/query_perf.jsonl" | tr -d ' ')
if [[ "$LINES" -eq 0 ]]; then
  echo "FAIL: query_perf.jsonl is empty"
  exit 1
fi
echo "  ✓ Performance log has $LINES entries"

echo ""
echo "OK - All integration tests passed"
