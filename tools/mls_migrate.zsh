#!/usr/bin/env bash
set -o pipefail

# mls_migrate.zsh — migrate old lessons (g/knowledge/mls_lessons.jsonl) → new ledger (mls/ledger/YYYY-MM-DD.jsonl)
#
# Usage:
#   tools/mls_migrate.zsh --plan     # Dry-run: show what would be migrated
#   tools/mls_migrate.zsh --apply    # Execute migration with backups
#
# Features:
# - Multi-line JSON source handling (via jq -c)
# - Backup creation (*.BAK) before writes
# - Idempotent writes (skip already migrated entries)
# - Histograms + detailed report

# Auto-detect BASE from script location if not set
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(dirname "$SCRIPT_DIR")}"
OLD="$BASE/g/knowledge/mls_lessons.jsonl"
LEDGER_DIR="$BASE/mls/ledger"
REPORT="$BASE/g/reports/mls/migration_report_v2.txt"
MODE="${1:---plan}"

# Validate mode
if [[ "$MODE" != "--plan" && "$MODE" != "--apply" ]]; then
  echo "❌ Invalid mode: $MODE"
  echo "Usage: $0 [--plan|--apply]"
  exit 1
fi

# Check source file
[[ -f "$OLD" ]] || { echo "❌ Old lessons not found: $OLD"; exit 1; }

# Create directories
mkdir -p "$LEDGER_DIR" "$(dirname "$REPORT")"

# Statistics
count_total=0
count_ok=0
count_skipped=0
count_duplicate=0
declare -A seen_ts
declare -A seen_id
declare -A type_hist
declare -A day_hist
dup_ts=0
missing_critical=0
SAMPLE="$BASE/g/reports/mls/migration_samples.jsonl"
: > "$SAMPLE"

# Helper: derive day (YYYY-MM-DD) from ts string
derive_day() {
  local ts="$1"
  if [[ -n "$ts" && "$ts" == 20??-* ]]; then
    echo "${ts:0:10}"
  else
    date +%Y-%m-%d
  fi
}

# Helper: check if entry already exists in ledger (idempotent check)
is_already_migrated() {
  local id="$1"
  local day="$2"
  local out="$LEDGER_DIR/$day.jsonl"

  if [[ ! -f "$out" ]]; then
    return 1  # File doesn't exist, not migrated
  fi

  # Check if ID exists in the ledger file
  if grep -q "\"id\":\"$id\"" "$out" 2>/dev/null; then
    return 0  # Already migrated
  fi

  return 1  # Not migrated
}

# Start report
echo "▶️ MLS Migration v2 ($MODE)" > "$REPORT"
echo "Source: $OLD" >> "$REPORT"
echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT"
echo "---" >> "$REPORT"

# Use flat version if available, otherwise flatten to temp file
if [[ -f "${OLD%.*}_flat.jsonl" ]]; then
  SOURCE_FILE="${OLD%.*}_flat.jsonl"
  echo "Using pre-flattened: $SOURCE_FILE" >> "$REPORT"
  CLEANUP_SOURCE=false
else
  # Flatten JSON to temp file first (handles both pretty-printed and single-line JSON)
  SOURCE_FILE="/tmp/mls_migrate_$$_flat.jsonl"
  jq -c '.' "$OLD" > "$SOURCE_FILE"
  echo "Flattened to: $SOURCE_FILE" >> "$REPORT"
  CLEANUP_SOURCE=true
fi

# Create jq filter file for complex transformation
JQ_FILTER="/tmp/mls_migrate_filter_$$.jq"

# Only cleanup temp files, not pre-existing flat file
if [[ "$CLEANUP_SOURCE" == "true" ]]; then
  trap "rm -f '$SOURCE_FILE' '$JQ_FILTER'" EXIT
else
  trap "rm -f '$JQ_FILTER'" EXIT
fi

cat > "$JQ_FILTER" << 'EOFFILTER'
{
  id: (.id // ("MLS-" + ($ts | gsub("[^0-9]"; "")[0:13]))),
  ts: $ts,
  type: (.type // "improvement"),
  title: (.title // "Untitled"),
  summary: (.summary // .description // "—"),
  memo: (.context // .memo // ""),
  source: {
    producer: "clc",
    context: (
      if (.context | type == "string") then
        if (.context | test("WO-|Work Order"; "i")) then "wo"
        elif (.context | test("CI|github|workflow"; "i")) then "ci"
        elif (.context | test("bridge"; "i")) then "bridge"
        else "local"
        end
      else
        "local"
      end
    ),
    session: (.related_session // .session // "")
  },
  links: {
    followup_id: (.followup_id // ""),
    wo_id: (
      if (.related_wo and (.related_wo == "none" | not) and (.related_wo | type=="string")) then
        (.related_wo | capture("^(?<id>WO-[0-9]+)").id // .related_wo)
      else
        ""
      end
    )
  },
  tags: (.tags // []),
  author: (.author // "clc"),
  confidence: ((.confidence // 0.8) | tonumber)
}
EOFFILTER

# Read flattened JSON line by line
while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  # Validate JSON
  if ! echo "$line" | jq -e . >/dev/null 2>&1; then
    ((count_skipped++))
    echo "skip: invalid json" >> "$REPORT"
    continue
  fi

  ((count_total++))

  # Extract fields with fallbacks
  id=$(echo "$line" | jq -r '.id // ""')
  ts=$(echo "$line" | jq -r '(.ts // .timestamp // "")')
  [[ "$ts" == "null" ]] && ts=""
  [[ -z "$ts" ]] && ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  day=$(derive_day "$ts")

  # Check for duplicate IDs
  if [[ -n "$id" && -n "${seen_id[$id]:-}" ]]; then
    ((count_duplicate++))
    echo "skip: duplicate id $id" >> "$REPORT"
    continue
  fi
  [[ -n "$id" ]] && seen_id[$id]=1

  # Check for duplicate timestamps
  if [[ -n "$ts" && -n "${seen_ts[$ts]:-}" ]]; then
    ((dup_ts++))
    echo "warn: duplicate ts $ts (id=$id)" >> "$REPORT"
  else
    [[ -n "$ts" ]] && seen_ts[$ts]=1
  fi

  # Validate critical fields
  title=$(echo "$line" | jq -r '.title // ""')
  desc=$(echo "$line" | jq -r '.description // .summary // ""')
  if [[ -z "$title" || -z "$desc" ]]; then
    ((missing_critical++))
    echo "warn: missing critical fields @ $ts (id=$id)" >> "$REPORT"
  fi

  # Build histograms
  tkey=$(echo "$line" | jq -r '.type // "(unset)"')
  [[ -z "${type_hist[$tkey]:-}" ]] && type_hist[$tkey]=0
  (( type_hist[$tkey]++ ))
  [[ -z "${day_hist[$day]:-}" ]] && day_hist[$day]=0
  (( day_hist[$day]++ ))

  # Save sample (first 5 entries)
  if [[ $(wc -l < "$SAMPLE" | tr -d ' ') -lt 5 ]]; then
    echo "$line" | jq -c . >> "$SAMPLE"
  fi

  # Transform to new schema using filter file
  new_json=$(echo "$line" | jq -c --arg ts "$ts" -f "$JQ_FILTER" 2>/dev/null)

  # Extract ID from transformed JSON for idempotent check
  new_id=$(echo "$new_json" | jq -r '.id // ""' 2>/dev/null)

  if [[ "$MODE" == "--plan" ]]; then
    # Dry-run: validate and show plan
    if echo "$new_json" | jq -e '.id and .ts and .type and .title and .summary and .source' >/dev/null 2>&1; then
      ((count_ok++))
      echo "$day: $title" >> "$REPORT"
    else
      ((count_skipped++))
      echo "skip: schema validation fail @ $ts (id=$new_id)" >> "$REPORT"
    fi
  else
    # --apply: write to ledger with backup and idempotent check
    out="$LEDGER_DIR/$day.jsonl"

    # Check if already migrated (idempotent)
    if is_already_migrated "$new_id" "$day"; then
      ((count_duplicate++))
      echo "skip: already migrated $new_id → $out" >> "$REPORT"
      continue
    fi

    # Create backup if file exists and not yet backed up
    if [[ -f "$out" && ! -f "$out.BAK" ]]; then
      cp "$out" "$out.BAK"
      echo "backup: created $out.BAK" >> "$REPORT"
    fi

    # Append to ledger (atomic append)
    printf '%s\n' "$new_json" >> "$out"
    ((count_ok++))
    echo "ok: $day: $title → $out" >> "$REPORT"
  fi
done < "$SOURCE_FILE"

# Generate histograms
echo "---" >> "$REPORT"
echo "📊 HISTOGRAMS" >> "$REPORT"
echo "" >> "$REPORT"

echo "By Type:" >> "$REPORT"
for type in "${!type_hist[@]}"; do
  printf "  %-15s %3d\n" "$type:" "${type_hist[$type]}" >> "$REPORT"
done
echo "" >> "$REPORT"

echo "By Day:" >> "$REPORT"
for day in $(echo "${!day_hist[@]}" | tr ' ' '\n' | sort); do
  printf "  %s  %3d\n" "$day" "${day_hist[$day]}" >> "$REPORT"
done
echo "" >> "$REPORT"

# Summary
echo "---" >> "$REPORT"
echo "📈 SUMMARY" >> "$REPORT"
echo "Total: $count_total | OK: $count_ok | Skipped: $count_skipped | Duplicates: $count_duplicate" >> "$REPORT"
[[ $dup_ts -gt 0 ]] && echo "⚠️  Duplicate timestamps: $dup_ts" >> "$REPORT"
[[ $missing_critical -gt 0 ]] && echo "⚠️  Missing critical fields: $missing_critical" >> "$REPORT"
echo "Finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT"

# Output to console
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MLS Migration v2 - $MODE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat "$REPORT"
echo ""
echo "📄 Report: $REPORT"
[[ "$MODE" == "--plan" ]] && echo "✅ To execute: $0 --apply"
