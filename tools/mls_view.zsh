#!/usr/bin/env bash
# ======================================================================
# MLS Viewer — unified viewer for MLS ledger entries
# Supports: daily JSONL ledgers + legacy database fallback
# Usage:
#   mls_view.zsh --today
#   mls_view.zsh --summary
#   mls_view.zsh --producer=cls --limit=5
#   mls_view.zsh --grep 'artifact' --type=solution
# ======================================================================

set -euo pipefail

# Resolve script directory and repo root (CI-friendly, no $HOME dependency)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LEDGER_DIR="$REPO_ROOT/mls/ledger"
LEGACY_DB="$REPO_ROOT/g/knowledge/mls_lessons.jsonl"
MLS_INDEX="$REPO_ROOT/g/knowledge/mls_index.json"

# Timezone alignment with mls_add.zsh (Asia/Bangkok)
export TZ="${TZ:-Asia/Bangkok}"

# LEDGER_FILE will be computed after parsing CLI options

# --- HELPERS ----------------------------------------------------------

die() {
  echo "❌ $1" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: mls_view.zsh [OPTIONS]

Options:
  --today              Show all entries from today
  --date YYYY-MM-DD    Pick a specific ledger date (local timezone)
  --file PATH          Read from an explicit ledger file (overrides --date/--today)
  --summary            Show summary statistics only (count by type, producer, context)
  --by TYPE=VALUE      Filter by field (e.g., type=solution, producer=cls)
  --producer=PROD      Filter by producer (cls, codex, clc, gemini)
  --grep PATTERN       Search in title/summary/tags
  --type=TYPE          Filter by type (solution, failure, improvement, pattern, antipattern)
  --context=CTX        Filter by context (ci, bridge, wo, local)
  --limit=N            Limit output to N entries (default: all)
  --json               Output as JSON (default: pretty table)

Examples:
  mls_view.zsh --today
  mls_view.zsh --summary
  mls_view.zsh --today --summary
  mls_view.zsh --by type=solution
  mls_view.zsh --producer=cls --limit=5
  mls_view.zsh --grep 'artifact'
  mls_view.zsh --type=solution --context=bridge
  mls_view.zsh --date 2025-11-10
  mls_view.zsh --file "$HOME/02luka/mls/ledger/2025-11-10.jsonl"
EOF
  exit 0
}

# --- PARSE ARGS -------------------------------------------------------

SHOW_TODAY=false
SHOW_SUMMARY=false
FILTER_BY=""
PRODUCER=""
GREP_PATTERN=""
TYPE=""
CONTEXT=""
LIMIT=""
JSON_OUTPUT=false
DATE_OVERRIDE=""
FILE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --today)
      SHOW_TODAY=true
      shift
      ;;
    --summary)
      SHOW_SUMMARY=true
      shift
      ;;
    --by)
      FILTER_BY="$2"
      shift 2
      ;;
    --producer=*)
      PRODUCER="${1#*=}"
      shift
      ;;
    --grep)
      GREP_PATTERN="$2"
      shift 2
      ;;
    --type=*)
      TYPE="${1#*=}"
      shift
      ;;
    --context=*)
      CONTEXT="${1#*=}"
      shift
      ;;
    --limit=*)
      LIMIT="${1#*=}"
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --date)
      DATE_OVERRIDE="$2"
      shift 2
      ;;
    --date=*)
      DATE_OVERRIDE="${1#*=}"
      shift
      ;;
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --file=*)
      FILE_PATH="${1#*=}"
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

# --- RESOLVE LEDGER FILE --------------------------------------------

# Precedence: --file > --date > --today/default
LEDGER_FILE=""
if [[ -n "$FILE_PATH" ]]; then
  LEDGER_FILE="$FILE_PATH"
else
  if [[ -n "$DATE_OVERRIDE" ]]; then
    if ! echo "$DATE_OVERRIDE" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
      die "Invalid --date format. Use YYYY-MM-DD"
    fi
    DAY="$DATE_OVERRIDE"
  else
    # --today or default to today
    DAY="$(date +%Y-%m-%d)"
  fi
  LEDGER_FILE="$LEDGER_DIR/${DAY}.jsonl"
fi

# --- VALIDATE ---------------------------------------------------------

command -v jq >/dev/null || die "jq not found"

# --- READ ENTRIES -----------------------------------------------------

# Try daily ledger first, fall back to legacy DB if not found or empty
USING_LEGACY=false
if [ ! -f "$LEDGER_FILE" ] || [ ! -s "$LEDGER_FILE" ]; then
  if [ -f "$LEGACY_DB" ]; then
    echo "ℹ️  Daily ledger not found or empty, using legacy database: $LEGACY_DB" >&2
    LEDGER_FILE="$LEGACY_DB"
    USING_LEGACY=true
  else
    die "Neither daily ledger ($LEDGER_FILE) nor legacy DB ($LEGACY_DB) found"
  fi
fi

ENTRIES=$(awk 'NF' "$LEDGER_FILE" | jq -s '.')

if [ -z "$ENTRIES" ] || [ "$ENTRIES" = "[]" ]; then
  echo "ℹ️  No entries found in $LEDGER_FILE"
  exit 0
fi

# Detect legacy format: check if first entry lacks source.producer field
if [ "$USING_LEGACY" = false ]; then
  HAS_SOURCE=$(echo "$ENTRIES" | jq -r '.[0].source.producer // "null"')
  [ "$HAS_SOURCE" = "null" ] && USING_LEGACY=true
fi

# Normalize legacy format to modern format
if [ "$USING_LEGACY" = true ]; then
  ENTRIES=$(echo "$ENTRIES" | jq '[.[] | {
    ts: (.timestamp // .ts),
    type: .type,
    title: .title,
    summary: (.description // .summary),
    memo: (.context // .memo // ""),
    source: {
      producer: "legacy",
      context: "legacy",
      session: (.related_session // "unknown")
    },
    links: {
      wo_id: (.related_wo // "")
    },
    tags: (.tags // []),
    author: "legacy",
    confidence: 0.5
  }]')
fi

# --- APPLY FILTERS (OPTIMIZED: single jq pass) -----------------------

# Build jq filter expression dynamically to reduce subprocess calls
JQ_FILTER='.'

# Start with array selection
if [ -n "$PRODUCER" ] || [ -n "$TYPE" ] || [ -n "$CONTEXT" ] || [ -n "$FILTER_BY" ] || [ -n "$GREP_PATTERN" ]; then
  JQ_FILTER='[.[] | select('
  FILTERS=()

  [ -n "$PRODUCER" ] && FILTERS+=("(.source.producer == \"$PRODUCER\")")
  [ -n "$TYPE" ] && FILTERS+=("(.type == \"$TYPE\")")
  [ -n "$CONTEXT" ] && FILTERS+=("(.source.context == \"$CONTEXT\")")

  if [ -n "$FILTER_BY" ]; then
    FIELD="${FILTER_BY%%=*}"
    VALUE="${FILTER_BY#*=}"
    FILTERS+=("(.\"$FIELD\" == \"$VALUE\")")
  fi

  if [ -n "$GREP_PATTERN" ]; then
    FILTERS+=("((.title | ascii_downcase | contains(\"$GREP_PATTERN\")) or (.summary | ascii_downcase | contains(\"$GREP_PATTERN\")) or ((.tags | type == \"array\") and (.tags[]? | ascii_downcase | contains(\"$GREP_PATTERN\"))))")
  fi

  # Join filters with AND operator
  FILTER_EXPR=""
  for i in "${!FILTERS[@]}"; do
    if [ $i -eq 0 ]; then
      FILTER_EXPR="${FILTERS[$i]}"
    else
      FILTER_EXPR="${FILTER_EXPR} and ${FILTERS[$i]}"
    fi
  done

  JQ_FILTER="${JQ_FILTER}${FILTER_EXPR})]"
else
  JQ_FILTER='.'
fi

# Add limit if specified
[ -n "$LIMIT" ] && JQ_FILTER="${JQ_FILTER} | .[:$LIMIT]"

# Apply all filters in ONE jq call
ENTRIES=$(echo "$ENTRIES" | jq "$JQ_FILTER")

# --- OUTPUT -----------------------------------------------------------

# Check if we have any entries after filtering
if [ -z "$ENTRIES" ] || [ "$ENTRIES" = "[]" ]; then
  echo "ℹ️  No entries match the specified filters"
  exit 0
fi

if [ "$SHOW_SUMMARY" = true ]; then
  # Show summary statistics (optimized: single jq call for all stats)
  STATS=$(echo "$ENTRIES" | jq -r '
    . as $entries |
    {
      count: ($entries | length),
      by_type: ($entries | group_by(.type) | map({type: .[0].type, count: length}) | sort_by(-.count)),
      by_producer: ($entries | group_by(.source.producer) | map({producer: .[0].source.producer, count: length}) | sort_by(-.count)),
      by_context: ($entries | group_by(.source.context) | map({context: .[0].source.context, count: length}) | sort_by(-.count)),
      first_ts: ($entries | map(.ts) | min),
      last_ts: ($entries | map(.ts) | max)
    } |
    "📊 MLS Summary Statistics\n=========================\n\nTotal entries: \(.count)\n\nBy Type:\n\(.by_type | map("  \(.type): \(.count)") | join("\n"))\n\nBy Producer:\n\(.by_producer | map("  \(.producer): \(.count)") | join("\n"))\n\nBy Context:\n\(.by_context | map("  \(.context): \(.count)") | join("\n"))\n\nDate Range:\n  First: \(.first_ts)\n  Last:  \(.last_ts)"
  ')
  echo -e "$STATS"

elif [ "$JSON_OUTPUT" = true ]; then
  echo "$ENTRIES" | jq '.'
else
  COUNT=$(echo "$ENTRIES" | jq 'length')
  echo "📊 Found $COUNT entries"
  echo ""

  echo "$ENTRIES" | jq -r '.[] |
    "\(.ts) | \(.type) | \(.title)
    Producer: \(.source.producer) | Context: \(.source.context // "N/A") | Workflow: \(.source.workflow // "N/A")
    Run ID: \(.source.run_id // "N/A") | Artifact: \(.source.artifact // "N/A") | Size: \(.source.artifact_size // "N/A") bytes
    Summary: \(.summary)
    Tags: \(.tags | join(", "))
    ---"'
fi

# ======================================================================
# Performance Notes:
# - Single jq pass for all filters (was 5+ separate calls)
# - Summary stats computed in one jq invocation
# - Repo-relative paths (CI-friendly, no $HOME dependency)
# - TZ-aware date handling aligned with mls_add.zsh
# - Legacy format auto-normalized to modern schema
# ======================================================================
