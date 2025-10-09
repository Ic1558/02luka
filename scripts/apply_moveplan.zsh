#!/usr/bin/env zsh
set -euo pipefail
PLAN="${1:?usage: apply_moveplan.zsh <reports/..._MOVEPLAN.tsv> [--apply]}"
APPLY="${2:-}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
UNDO="$PLAN.undo.zsh"

safe_mv() {
  local src="$1" dst="$2"
  local base="${dst##*/}" dir="${dst%/*}" stem="${base%.*}" ext="${base##*.}"
  [[ "$dir" == "$base" ]] && dir="."
  mkdir -p "$dir"
  local cand="$dst" n=1
  while [[ -e "$cand" ]]; do
    if [[ "$base" == "$ext" ]]; then
      cand="$dir/${base}-${n}"
    else
      cand="$dir/${stem}-${n}.${ext}"
    fi
    ((n++))
  done
  mv "$src" "$cand"
  echo "mv \"$cand\" \"$src\"" >> "$UNDO"
  echo "$cand"
}

echo "#!/usr/bin/env zsh" > "$UNDO"
echo "set -euo pipefail" >> "$UNDO"

# dry-run preview
tail -n +2 "$PLAN" | awk -F'\t' '{printf "PLAN: %s -> %s (%s)\n",$1,$2,$3}'

if [[ "$APPLY" == "--apply" ]]; then
  echo "---- APPLYING ----"
  while IFS=$'\t' read -r SRC DST REASON; do
    [[ -z "$SRC" || "$SRC" == "SRC" ]] && continue
    [[ -f "$ROOT/$SRC" ]] || continue
    NEW=$(safe_mv "$ROOT/$SRC" "$ROOT/$DST")
    echo "Moved: $SRC → ${NEW#"$ROOT/"}"
  done < "$PLAN"
  chmod +x "$UNDO"
  echo "✅ Done. Undo script: $UNDO"
else
  echo "Dry-run only. To apply: $0 \"$PLAN\" --apply"
fi
