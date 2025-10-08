#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "Generating boss catalogs..."

# helper: read front-matter key (very lightweight)
fm_get() { # fm_get <file> <key>
  awk '
    BEGIN{FS=": *"; in=0}
    /^---[[:space:]]*$/{in=!in; next}
    in && $1==key {print $2; exit}
  ' key="$2" "$1" 2>/dev/null
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
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  # build TSV: project \t name \t relpath
  while IFS= read -r -d '' f; do
    p="$(fm_get "$f" project)"; [ -z "$p" ] && p="(none)"
    n="$(basename "$f")"
    echo -e "$p\t$n\t../../g/reports/$n" >> "$tmp"
  done < <(find "$ROOT/g/reports" -maxdepth 1 -type f -name "*.md" -print0)
  # print grouped (top 5 projects alphabetically)
  awk -F'\t' '{print $0}' "$tmp" | sort -f | awk -F'\t' '
    BEGIN{cur=""; count=0}
    {
      if($1!=cur){
        if(cur!="" && count>0) print "";
        cur=$1; count=0;
        print "### " cur
      }
      print "- [" $2 "](" $3 ")"; count++
    }'
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
