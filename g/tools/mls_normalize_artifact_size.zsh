#!/usr/bin/env zsh
# ======================================================================
# MLS Normalize Artifact Size — backfill artifact_size for old entries
# Usage:
#   mls_normalize_artifact_size.zsh
# ======================================================================

set -euo pipefail

BASE="$HOME/02luka"
LEDGER_DIR="$BASE/mls/ledger"
STATUS_DIR="$BASE/mls/status"
BACKUP_DIR="$BASE/mls/backup_ledger_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

# --- HELPERS ----------------------------------------------------------

stat_size() {
  local p="$1"
  if [[ -f "$p" ]]; then
    stat -f%z "$p" 2>/dev/null || stat -c%s "$p" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# --- BACKUP -----------------------------------------------------------

echo "📦 Backing up ledgers to: $BACKUP_DIR"
cp -a "$LEDGER_DIR"/*.jsonl "$BACKUP_DIR"/ 2>/dev/null || true

updated_files=0
updated_lines=0

# --- PROCESS FILES -----------------------------------------------------

for f in "$LEDGER_DIR"/*.jsonl(N); do
  tmp="$(mktemp)"
  touched=false

  # Process each line (JSONL)
  while IFS= read -r line || [[ -n "${line:-}" ]]; do
    [[ -z "${line// }" ]] && continue

    if ! echo "$line" | jq -e . >/dev/null 2>&1; then
      # If not JSON, pass through as-is
      printf '%s\n' "$line" >> "$tmp"
      continue
    fi

    run_id="$(echo "$line" | jq -r '.source.run_id // empty')"
    art_path="$(echo "$line" | jq -r '.source.artifact_path // empty')"
    has_size="$(echo "$line" | jq -r 'has("source") and (.source|has("artifact_size"))')"

    if [[ "$has_size" != "true" ]]; then
      # Try to calculate size from various paths
      size=""

      if [[ -n "$art_path" ]]; then
        for p in "$art_path" "$BASE/$art_path" \
                 "$BASE/__artifacts__/cls_strict/selfcheck.json" \
                 "$BASE/__artifacts__/bridge/selfcheck.json"
        do
          size="$(stat_size "$p")"
          [[ -n "$size" ]] && break
        done
      fi

      # Try to get from summary file with matching run_id (if exists)
      if [[ -z "$size" && -n "$run_id" ]]; then
        candidate="$(grep -l "\"run_id\": \"$run_id\"" "$STATUS_DIR"/*_ci_cls_codex_summary.json 2>/dev/null | head -n1 || true)"
        if [[ -n "$candidate" ]]; then
          size="$(jq -r '.runs.last_strict.artifact.size_bytes // empty' "$candidate" 2>/dev/null || echo "")"
        fi
      fi

      [[ -z "$size" ]] && size="0"  # If not found, set to 0 for consistency

      line="$(echo "$line" | jq --argjson s "$size" '.source.artifact_size = $s')"
      touched=true
      (( updated_lines+=1 ))
    fi

    printf '%s\n' "$line" >> "$tmp"
  done < "$f"

  if [[ "$touched" == true ]]; then
    mv "$tmp" "$f"
    (( updated_files+=1 ))
  else
    rm -f "$tmp"
  fi
done

echo "✅ Normalize complete. Files updated: $updated_files, entries patched: $updated_lines"
echo "🗂  Backup kept at: $BACKUP_DIR"

