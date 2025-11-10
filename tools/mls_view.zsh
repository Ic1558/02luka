#!/usr/bin/env zsh
# ======================================================================
# MLS Viewer — quick terminal viewer for MLS ledger entries
# Usage:
#   mls_view.zsh --today
#   mls_view.zsh --by type=solution
#   mls_view.zsh --producer=cls
#   mls_view.zsh --grep 'artifact'
# ======================================================================

set -euo pipefail

LEDGER_DIR="$HOME/02luka/mls/ledger"
DAY="$(date +%Y-%m-%d)"
LEDGER="$LEDGER_DIR/${DAY}.jsonl"

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
  --by TYPE=VALUE      Filter by field (e.g., type=solution, producer=cls)
  --producer=PROD      Filter by producer (cls, codex, clc, gemini)
  --grep PATTERN       Search in title/summary/tags
  --type=TYPE          Filter by type (solution, failure, improvement, pattern, antipattern)
  --context=CTX        Filter by context (ci, bridge, wo, local)
  --limit=N            Limit output to N entries (default: all)
  --json               Output as JSON (default: pretty table)

Examples:
  mls_view.zsh --today
  mls_view.zsh --by type=solution
  mls_view.zsh --producer=cls --limit=5
  mls_view.zsh --grep 'artifact'
  mls_view.zsh --type=solution --context=bridge
EOF
  exit 0
}

# --- PARSE ARGS -------------------------------------------------------

SHOW_TODAY=false
FILTER_BY=""
PRODUCER=""
GREP_PATTERN=""
TYPE=""
CONTEXT=""
LIMIT=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --today)
      SHOW_TODAY=true
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
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

# --- VALIDATE ---------------------------------------------------------

if [ ! -f "$LEDGER" ]; then
  die "Ledger file not found: $LEDGER"
fi

command -v jq >/dev/null || die "jq not found"

# --- READ ENTRIES -----------------------------------------------------

ENTRIES=$(awk 'NF' "$LEDGER" | jq -s '.')

if [ -z "$ENTRIES" ] || [ "$ENTRIES" = "[]" ]; then
  echo "ℹ️  No entries found in $LEDGER"
  exit 0
fi

# --- APPLY FILTERS ----------------------------------------------------

# Filter by producer
if [ -n "$PRODUCER" ]; then
  ENTRIES=$(echo "$ENTRIES" | jq "[.[] | select(.source.producer == \"$PRODUCER\")]")
fi

# Filter by type
if [ -n "$TYPE" ]; then
  ENTRIES=$(echo "$ENTRIES" | jq "[.[] | select(.type == \"$TYPE\")]")
fi

# Filter by context
if [ -n "$CONTEXT" ]; then
  ENTRIES=$(echo "$ENTRIES" | jq "[.[] | select(.source.context == \"$CONTEXT\")]")
fi

# Filter by --by field=value
if [ -n "$FILTER_BY" ]; then
  FIELD="${FILTER_BY%%=*}"
  VALUE="${FILTER_BY#*=}"
  ENTRIES=$(echo "$ENTRIES" | jq "[.[] | select(.\"$FIELD\" == \"$VALUE\")]")
fi

# Grep in title/summary/tags
if [ -n "$GREP_PATTERN" ]; then
  ENTRIES=$(echo "$ENTRIES" | jq "[.[] | select(.title | ascii_downcase | contains(\"$GREP_PATTERN\")) or select(.summary | ascii_downcase | contains(\"$GREP_PATTERN\")) or select(.tags[]? | ascii_downcase | contains(\"$GREP_PATTERN\"))]")
fi

# Limit
if [ -n "$LIMIT" ]; then
  ENTRIES=$(echo "$ENTRIES" | jq ".[:$LIMIT]")
fi

# --- OUTPUT -----------------------------------------------------------

if [ "$JSON_OUTPUT" = true ]; then
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

