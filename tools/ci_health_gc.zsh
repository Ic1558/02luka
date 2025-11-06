#!/usr/bin/env zsh
set -euo pipefail

BASE="${BASE:-$HOME/02luka}"
DAYS="7"             # default keep > N days
MODE="dry"           # dry|force
ALL=0                # if 1 => ignore age filter
PRUNE_EMPTY=1        # if 0 => do NOT prune empty dirs (even in --force)

# Parse args: ci_health_gc.zsh [DAYS] [--force] [--all] [--no-prune-empty]
args=("$@")
for a in "${args[@]}"; do
  if [[ "$a" == "--force" ]]; then MODE="force"
  elif [[ "$a" == "--all" ]]; then ALL=1
  elif [[ "$a" == "--no-prune-empty" ]]; then PRUNE_EMPTY=0
  elif [[ "$a" == [0-9]## ]]; then DAYS="$a"
  fi
done

TARGETS=(
  "$BASE/tools/puppeteer/.logs"
  "$BASE/tools/puppeteer/.tmp"
  "$BASE/.tmp"
)

echo "🧽 CI Health GC"
echo "• Base     : $BASE"
echo "• Targets  :"; for t in "${TARGETS[@]}"; do echo "  - $t"; done
echo "• Mode     : $MODE"
echo "• Prune empty dirs: $([[ $PRUNE_EMPTY -eq 1 ]] && echo YES || echo NO)"
if [[ "$ALL" -eq 1 ]]; then
  echo "• Scope    : ALL files (ignoring age)"
else
  echo "• Older than: ${DAYS} days"
fi

echo "\n📦 Size before:"
for t in "${TARGETS[@]}"; do [[ -d "$t" ]] && du -sh "$t" 2>/dev/null || true; done

# Build candidate list
candidates=()
for t in "${TARGETS[@]}"; do
  [[ -d "$t" ]] || continue
  if [[ "$ALL" -eq 1 ]]; then
    while IFS= read -r f; do candidates+=("$f"); done < <(find "$t" -type f 2>/dev/null || true)
  else
    while IFS= read -r f; do candidates+=("$f"); done < <(find "$t" -type f -mtime +"$DAYS" 2>/dev/null || true)
  fi
done

if (( ${#candidates[@]} == 0 )); then
  echo "✅ No files matched."
  exit 0
fi

echo "\n🔎 Candidates (${#candidates[@]}):"
for f in "${candidates[@]}"; do echo "  - $f"; done

if [[ "$MODE" == "force" ]]; then
  echo "\n🗑️  Deleting..."
  for f in "${candidates[@]}"; do rm -f -- "$f"; done
  echo "✅ Deleted ${#candidates[@]} file(s)."
else
  echo "\nℹ️  Dry-run only. Use '--force' to actually delete."
fi

# Optional: prune empty dirs (respect --no-prune-empty)
if [[ "$PRUNE_EMPTY" -eq 1 ]]; then
  for t in "${TARGETS[@]}"; do
    [[ -d "$t" ]] || continue
    find "$t" -type d -empty -mindepth 1 -maxdepth 5 -print0 2>/dev/null \
      | xargs -0 -I{} echo "  ○ empty: {}" || true
    if [[ "$MODE" == "force" ]]; then
      find "$t" -type d -empty -mindepth 1 -maxdepth 5 -delete 2>/dev/null || true
    fi
  done
else
  echo "↪️  Skipping prune empty dirs (requested)."
fi

echo "\n📦 Size after:"
for t in "${TARGETS[@]}"; do [[ -d "$t" ]] && du -sh "$t" 2>/dev/null || true; done
