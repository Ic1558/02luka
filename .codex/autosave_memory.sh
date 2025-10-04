#!/usr/bin/env bash
set -euo pipefail
SRC=".codex/hybrid_memory_system.md"
DEST_DIR="g/reports/memory_autosave"
mkdir -p "$DEST_DIR"
TS=$(date +%Y%m%d_%H%M%S)
cp -f "$SRC" "$DEST_DIR/autosave_${TS}.md"
echo "🧠 Memory autosaved → $DEST_DIR/autosave_${TS}.md"
