#!/usr/bin/env zsh
# AP/IO v3.1 Correlation ID Generator
# Purpose: Generate unique correlation IDs for event chains

set -euo pipefail

# Generate correlation ID: corr-YYYYMMDD-NNN
DATE=$(date +%Y%m%d)
# Use microseconds or process ID for uniqueness
if command -v gdate >/dev/null 2>&1; then
  # macOS with GNU date
  MICROSEC=$(gdate +%N | head -c 3)
elif [ -n "${EPOCHREALTIME:-}" ]; then
  # Bash 5.0+ with EPOCHREALTIME
  MICROSEC=$(echo "$EPOCHREALTIME" | sed 's/.*\.\(...\).*/\1/')
else
  # Fallback: use process ID modulo 1000
  MICROSEC=$(($$ % 1000))
fi
# Ensure 3 digits
MICROSEC=$(printf "%03d" "$MICROSEC")
CORR_ID="corr-${DATE}-${MICROSEC}"

echo "$CORR_ID"
exit 0
