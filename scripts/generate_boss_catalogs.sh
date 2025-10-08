#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "Generating boss catalogs..."

# helper: read front-matter key (very lightweight)
fm_get() { # fm_get <file> <key>
  awk -v key="$2" '
    BEGIN{FS=": *"; inside=0}
    /^---[[:space:]]*$/{inside=!inside; next}
    inside && $1==key {print $2; exit}
  ' "$1" 2>/dev/null
}

# boss/reports/index.md
{
  echo "# Reports Catalog (Auto-Generated)"
  echo
  echo "**Last Updated:** $(date -Iseconds)"
  echo
  echo "## Latest Reports (Last 50)"
  echo
  find "$ROOT/g/reports" -maxdepth 1 -type f -name "*.md" -print0 \
    | xargs -0 ls -t 2>/dev/null | head -50 | while read -r f; do
      name=$(basename "$f")
      echo "- [$name](../../g/reports/$name)"
    done || true
  echo
  echo "## Proof Evidence"
  echo
  find "$ROOT/g/reports/proof" -type f -name "*.md" -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null | head -10 | while read -r f; do
      name=$(basename "$f")
      echo "- [$name](../../g/reports/proof/$name)"
    done || true

  # By Project (from front-matter 'project:')
  echo
  echo "## By Project"
  TMP="$(mktemp)"
  while IFS= read -r -d '' F; do
    P="$(fm_get "$F" project)"; [ -z "$P" ] && P="(none)"
    N="$(basename "$F")"
    printf "%s\t%s\t../../g/reports/%s\n" "$P" "$N" "$N" >> "$TMP"
  done < <(find "$ROOT/g/reports" -maxdepth 1 -type f -name "*.md" -print0)
  sort -t$'\t' -k1,1 "$TMP" | awk -F'\t' 'BEGIN{cur=""} {if($1!=cur){if(cur!="")print ""; print "### " $1; cur=$1} print "- [" $2 "](" $3 ")"}'
  rm -f "$TMP"
} > "$ROOT/boss/reports/index.md"

# boss/memory/index.md
{
  echo "# Memory Catalog (Auto-Generated)"
  echo
  echo "**Last Updated:** $(date -Iseconds)"
  echo
  for agent in clc gg gc mary paula codex boss; do
    echo "## $agent (latest 20)"
    dir="$ROOT/memory/$agent"
    if [ -d "$dir" ]; then
      find "$dir" -maxdepth 1 -type f -name "*.md" -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null | head -20 | while read -r f; do
            name=$(basename "$f")
            echo "- [$name](../../memory/$agent/$name)"
          done || true
    else
      echo "- (no sessions yet)"
    fi
    echo
  done
} > "$ROOT/boss/memory/index.md"

echo "✅ Boss catalogs updated:"
echo "  - boss/reports/index.md"
echo "  - boss/memory/index.md"
