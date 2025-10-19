#!/usr/bin/env bash
# Remember successful task execution in vector memory
# Usage: remember_task.sh --kind <kind> --text <text> [--meta-key value ...]

set -euo pipefail

# Source universal path resolver
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/repo_root_resolver.sh"

KIND=""
TEXT=""
META_ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kind)
      KIND="$2"
      shift 2
      ;;
    --text)
      TEXT="$2"
      shift 2
      ;;
    --meta-*)
      META_KEY="${1#--meta-}"
      META_VALUE="$2"
      META_ARGS+=("--meta-$META_KEY" "$META_VALUE")
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$KIND" ]] || [[ -z "$TEXT" ]]; then
  echo "Usage: remember_task.sh --kind <kind> --text <text> [--meta-key value ...]" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  remember_task.sh --kind plan --text 'Implemented Discord integration'" >&2
  echo "  remember_task.sh --kind solution --text 'Fixed macOS date command' --meta-commit abc123" >&2
  exit 1
fi

# Call memory system
if ! command -v node >/dev/null 2>&1; then
  echo "Error: node is required for memory system" >&2
  exit 1
fi

# Build Node.js call with metadata
# For now, metadata is not fully supported via CLI, but we can extend later
node "$REPO_ROOT/memory/index.cjs" --remember "$KIND" "$TEXT"
