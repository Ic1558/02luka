#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AGENT="${AGENT:-clc}"
DIR="$ROOT/memory/$AGENT"; mkdir -p "$DIR"
TS="$(date +%y%m%d_%H%M%S)"
TITLE="${1:-note}"
SLUG="$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')"
OUT="$DIR/session_${TS}_${SLUG}.md"
{
  echo "# $TITLE"
  echo
  echo "- Agent: $AGENT"
  echo "- Created: $(date -Iseconds)"
  echo
} > "$OUT"
echo "✅ $OUT"
