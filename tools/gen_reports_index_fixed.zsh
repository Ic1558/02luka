#!/usr/bin/env zsh
set -euo pipefail
BASE="$HOME/02luka/g/reports"
mkdir -p "$BASE"
OUT="$BASE/INDEX.md"

{
  echo "# 📊 Reports Index"
  echo ""
  echo "Generated: $(date '+%F %T %Z')"
  echo ""
  echo "## Quick Links"
  echo ""
  echo "- [Latest Phase Reports](./latest/) (Phase 10-12)"
  echo "- [Session Logs](./sessions/)"
  echo ""

  if [[ -d "$BASE" ]]; then
    for d in $(find "$BASE" -maxdepth 1 -type d -not -path "$BASE" 2>/dev/null | sort); do
      rel=${d#$BASE/}
      rel=${rel#/}
      count=$(find "$d" -type f \( -name '*.md' -o -name '*.txt' \) 2>/dev/null | wc -l | tr -d ' ')
      echo "## 📁 $rel ($count files)"
      echo ""

      find "$d" -type f \( -name '*.md' -o -name '*.txt' \) 2>/dev/null | sort | while read file; do
        relf=${file#$BASE/}
        relf=${relf#/}
        fname=$(basename "$file")
        size=$(du -h "$file" 2>/dev/null | cut -f1)
        echo "- [$fname](./$relf) ($size)"
      done
      echo ""
    done
  fi
} > "$OUT"

echo "✅ Generated: $OUT"
