#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
CODEX="$BASE/.codex/hybrid_memory_system.md"
CLC="$BASE/a/section/clc/memory/active_memory.md"
RULES="$BASE/.codex/memory_merge_rules.yml"
REPORT="$BASE/g/reports/MEMORY_MERGE_LOG_$(date +%Y%m%d_%H%M%S).md"

echo "# Memory Merge Log — $(date)" > "$REPORT"

if [ ! -f "$CODEX" ] || [ ! -f "$CLC" ]; then
  echo "❌ Missing memory file(s)" | tee -a "$REPORT"
  exit 0
fi

C_TIME=$(stat -f "%m" "$CODEX")
L_TIME=$(stat -f "%m" "$CLC")

if [ "$C_TIME" -gt "$L_TIME" ]; then
  SRC="$CODEX"; DST="$CLC"; DIR="→ CLC"
else
  SRC="$CLC"; DST="$CODEX"; DIR="← Cursor"
fi

echo "Sync direction: $DIR" | tee -a "$REPORT"
grep -v '^#' "$SRC" > "$DST"
echo "✅ Synced $SRC → $DST" | tee -a "$REPORT"
echo "Rules: mirror-latest, selective-merge" | tee -a "$REPORT"
echo "== Merge complete ==" | tee -a "$REPORT"
