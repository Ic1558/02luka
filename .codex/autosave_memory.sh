#!/usr/bin/env bash
set -euo pipefail
TS=$(date +%Y%m%d_%H%M%S)
DEST=".codex/autosave/hybrid_memory_${TS}.md"
mkdir -p .codex/autosave
cp .codex/hybrid_memory_system.md "$DEST"
echo "🧠 Memory autosaved to $DEST"
