#!/usr/bin/env zsh
# Search MLS lessons by keyword and optional type.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed"
  echo "Install: brew install jq"
  exit 1
fi

MLS_DB="${MLS_DB:-$HOME/02luka/g/knowledge/mls_lessons.jsonl}"

usage() {
  cat <<'USAGE'
Usage: mls_search.zsh <keyword> [type]

Examples:
  mls_search.zsh sync
  mls_search.zsh "" solution
  mls_search.zsh merge failure
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

KEYWORD="$1"
TYPE="${2:-}"

if [[ ! -f "$MLS_DB" ]]; then
  echo "No MLS database found at $MLS_DB" >&2
  exit 1
fi

if [[ ! -s "$MLS_DB" ]]; then
  echo "No lessons found."
  exit 0
fi

RESULTS=$(jq -s -r \
  --arg keyword "$KEYWORD" \
  --arg type "$TYPE" \
  '
  def lc: ascii_downcase;
  def text: [(.title // ""), (.description // ""), (.context // "")] | join(" ");
  def match_keyword:
    if ($keyword | length) == 0 then true
    else (text | lc | contains($keyword | lc))
    end;
  def match_type:
    if ($type | length) == 0 then true
    else ((.type // "") == $type)
    end;
  map(select(match_keyword and match_type))
  | .[]
  | "\(.id // "-")\t\(.type // "-")\t\(.timestamp // "-")\t\(.title // "-")"
  ' "$MLS_DB" 2>/dev/null)

if [[ -z "$RESULTS" ]]; then
  echo "No lessons found."
  exit 0
fi

echo "$RESULTS"
