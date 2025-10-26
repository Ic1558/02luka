#!/usr/bin/env bash
# Safe shell wrapper for hybrid search
# Usage: tools/hybrid_search.sh "query string" [top_k] [mode] [print_snippet]
#   - query: search query (required, max 2000 chars)
#   - top_k: number of results (default: 8)
#   - mode: hybrid|verify|fts (default: hybrid)
#   - print_snippet: true|false (default: false)

set -euo pipefail

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
QUERY="${1:-}"
TOP_K="${2:-8}"
MODE="${3:-hybrid}"
PRINT_SNIPPET="${4:-false}"

# Validation
if [[ -z "$QUERY" ]]; then
  echo "Error: Query string required" >&2
  echo "Usage: $0 \"query string\" [top_k] [mode] [print_snippet]" >&2
  exit 1
fi

# Length cap: 2000 characters
if [[ ${#QUERY} -gt 2000 ]]; then
  echo "Error: Query exceeds 2000 character limit (got ${#QUERY})" >&2
  exit 1
fi

# Validate mode
if [[ ! "$MODE" =~ ^(hybrid|verify|fts)$ ]]; then
  echo "Error: Invalid mode '$MODE'. Use: hybrid, verify, or fts" >&2
  exit 1
fi

# Build node command based on mode
cd "$REPO_ROOT"

case "$MODE" in
  hybrid)
    node knowledge/index.cjs --hybrid "$QUERY" --k="$TOP_K"
    ;;
  verify)
    node knowledge/index.cjs --verify "$QUERY" --k="$TOP_K"
    ;;
  fts)
    node knowledge/index.cjs --search "$QUERY"
    ;;
  *)
    echo "Error: Unknown mode '$MODE'" >&2
    exit 1
    ;;
esac
