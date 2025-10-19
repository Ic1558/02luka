#!/usr/bin/env bash
# Automated memory cleanup script (Phase 6.5-A)
# Removes old or low-importance memories to keep the vector index lean

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_CLI="$REPO_ROOT/memory/index.cjs"

# Default parameters (can be overridden via environment variables)
MAX_AGE_DAYS="${MEMORY_CLEANUP_MAX_AGE:-90}"
MIN_IMPORTANCE="${MEMORY_CLEANUP_MIN_IMPORTANCE:-0.3}"

# Logging
echo "=== Memory Cleanup Started ==="
echo "Date: $(date)"
echo "Max Age: $MAX_AGE_DAYS days"
echo "Min Importance: $MIN_IMPORTANCE"
echo ""

# Check if memory module exists
if [ ! -f "$MEMORY_CLI" ]; then
  echo "❌ Error: Memory module not found at $MEMORY_CLI"
  exit 1
fi

# Check if node is available
if ! command -v node >/dev/null 2>&1; then
  echo "❌ Error: Node.js not found"
  exit 1
fi

# Get stats before cleanup
echo "📊 Memory stats before cleanup:"
node "$MEMORY_CLI" --stats
echo ""

# Run cleanup
echo "🧹 Running cleanup..."
node "$MEMORY_CLI" --cleanup --maxAge "$MAX_AGE_DAYS" --minImportance "$MIN_IMPORTANCE"
echo ""

# Get stats after cleanup
echo "📊 Memory stats after cleanup:"
node "$MEMORY_CLI" --stats
echo ""

echo "=== Memory Cleanup Complete ==="
echo "Date: $(date)"

exit 0
