#!/usr/bin/env zsh
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found" >&2
  exit 1
fi

R="$HOME/02luka"
OUT="$R/mls/rnd/lessons.jsonl"

mkdir -p "${OUT:h}"

ts(){ date -u +"%Y-%m-%dT%H:%M:%SZ"; }

jq -n --arg ts "$(ts)" --arg id "$1" --arg pr "$2" --arg outcome "$3" \
  '{ts:$ts,id:$id,pr:$pr,outcome:$outcome}' >> "$OUT"

echo "appended → $OUT"
