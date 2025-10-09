#!/usr/bin/env zsh
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT_DIR="$ROOT/g/reports/proof"; mkdir -p "$OUT_DIR"
TS="$(date +%y%m%d_%H%M)"
PLAN="$OUT_DIR/${TS}_MOVEPLAN.tsv"

# allowlists
typeset -A allow_root
for k in Makefile README.md package.json package-lock.json playwright.config.ts .gitignore .gitattributes .dockerignore; do
  allow_root[$k]=1
done

is_report() { [[ "$1" =~ '\.(md|html)' ]] }

echo -e "SRC\tDST\tREASON" > "$PLAN"

# root-only scan (ไม่แตะ memory/ และ boss catalogs)
for f in "$ROOT"/*; do
  base="$(basename "$f")"
  [[ -f "$f" ]] || continue
  [[ -n "${allow_root[$base]-}" ]] && continue
  case "$base" in
    report*|analysis*|summary*|*.md)
      echo -e "${base}\tdocs/${base}\tout-of-zone" >> "$PLAN";;
    *.sh|*.zsh|*.py)
      echo -e "${base}\tscripts/${base}\tout-of-zone" >> "$PLAN";;
    *.bak|*.old|*.tmp|*~)
      echo -e "${base}\t.trash/$TS/${base}\tbackup" >> "$PLAN";;
    *)
      : ;;
  esac
done

# skip bosses & memory
# boss catalogs are correct; memory is SOT → no entries added

echo "✅ Move plan → $PLAN"
