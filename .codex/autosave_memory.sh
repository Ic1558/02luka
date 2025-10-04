#!/usr/bin/env bash
set -euo pipefail
LOCK=".codex/locks/autosave.lock"
LAST_HASH_FILE=".codex/.last_autosave_hash"
OUTDIR="g/reports/memory_autosave"
RUN_ID="${RUN_ID:-$(hostname)-$$}"

# ล็อกแบบ non-blocking: ถ้ามีคนใช้อยู่ ให้จบเงียบๆ
LOCK_FALLBACK=.codex/locks/autosave.mutex
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK" || true
  if ! flock -n 9; then echo "[autosave] another process is saving; skip"; exit 0; fi
else
  mkdir -p .codex/locks >/dev/null 2>&1 || true
  if ! mkdir "$LOCK_FALLBACK" 2>/dev/null; then echo "[autosave] another process is saving (fallback); skip"; exit 0; fi
fi
exec 9>"$LOCK" || true
if ! flock -n 9; then
  echo "[autosave] another process is saving; skip"
  exit 0
fi

# รวมแหล่งความจำ (ถ้ามี)
TMP="$(mktemp)"
[ -f ".codex/hybrid_memory_system.md" ] && echo "## CODEx Hybrid" >>"$TMP" && cat ".codex/hybrid_memory_system.md" >>"$TMP"
[ -d "a/section/clc/memory" ] && echo "## CLC Memory" >>"$TMP" && find a/section/clc/memory -type f -maxdepth 1 -name "*.md" -print0 | xargs -0 -I{} sh -c 'echo "--- {} ---"; cat "{}"' >>"$TMP" || true

# แฮชเพื่อตรวจซ้ำ (normalize ด้วย sha256)
CUR_HASH="$(shasum -a 256 "$TMP" | awk '{print $1}')"
LAST_HASH="$(cat "$LAST_HASH_FILE" 2>/dev/null || echo '')"

if [ "$CUR_HASH" = "$LAST_HASH" ]; then
  echo "[autosave] unchanged content; skip"
  rm -f "$TMP"
  exit 0
fi

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$OUTDIR/autosave_${TS}_${CUR_HASH}_${RUN_ID}.md"
{
  echo "---"
  echo "run_id: \"$RUN_ID\""
  echo "hash: \"$CUR_HASH\""
  echo "timestamp: \"$TS\""
  echo "---"
  cat "$TMP"
} > "$OUT"

echo "$CUR_HASH" > "$LAST_HASH_FILE"
rm -f "$TMP"
echo "[autosave] wrote $OUT"
trap 'rm -rf "$LOCK_FALLBACK" >/dev/null 2>&1 || true' EXIT
