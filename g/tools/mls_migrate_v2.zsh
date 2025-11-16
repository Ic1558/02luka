#!/usr/bin/env zsh
# MLS Migration v2 - Simple, working version

BASE="$HOME/02luka"
SRC="$BASE/g/knowledge/mls_lessons_flat.jsonl"
OUT_DIR="$BASE/mls/ledger"
REPORT="$BASE/g/reports/mls/migration_report_v2.txt"
MODE="${1:---dry-run}"

[[ -f "$SRC" ]] || { echo "❌ Source not found: $SRC"; exit 1; }
mkdir -p "$OUT_DIR" "$(dirname "$REPORT")"

echo "▶️ MLS Migration v2 ($MODE)" | tee "$REPORT"
echo "Source: $SRC" | tee -a "$REPORT"
echo "---" | tee -a "$REPORT"

total=0
ok=0
failed=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  ((total++))

  # Extract date
  ts=$(echo "$line" | jq -r '.timestamp // .ts // ""')
  day="${ts:0:10}"
  [[ -z "$day" || "$day" == "null" ]] && day=$(date +%Y-%m-%d)

  # Transform
  out=$(echo "$line" | jq -c '{
    ts: (.timestamp // .ts),
    type: .type,
    title: .title,
    summary: (.description // .summary),
    memo: .context,
    source: {
      producer: "clc",
      context: (if (.context | test("WO-")) then "wo" elif (.context | test("CI|github")) then "ci" else "local" end),
      session: .related_session
    },
    links: {
      wo_id: ((.related_wo // "") | match("^(WO-[0-9]+)") | .captures[0].string // null)
    },
    tags: .tags,
    author: "clc",
    confidence: 0.8
  }' 2>/dev/null || echo "$line" | jq -c '{
    ts: (.timestamp // .ts),
    type: .type,
    title: .title,
    summary: (.description // .summary),
    memo: .context,
    source: {producer: "clc", context: "local", session: .related_session},
    links: {wo_id: null},
    tags: .tags,
    author: "clc",
    confidence: 0.8
  }')

  if [[ "$MODE" == "--run" ]]; then
    echo "$out" >> "$OUT_DIR/$day.jsonl"
  fi

  echo "$day: $(echo "$out" | jq -r '.title')" | tee -a "$REPORT"
  ((ok++))
done < "$SRC"

echo "---" | tee -a "$REPORT"
echo "Total: $total | OK: $ok | Failed: $failed" | tee -a "$REPORT"
