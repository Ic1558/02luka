#!/usr/bin/env zsh
# AP/IO v3.1 Correlation ID Generator
# Purpose: Generate unique correlation IDs for event chains

set -euo pipefail

# Generate correlation ID format: corr-YYYYMMDD-NNN
# Where NNN is a sequence number (001-999)

DATE_PART=$(date +%Y%m%d)

# Try to get a unique sequence number
# Use microseconds if available, otherwise use process ID
if command -v gdate >/dev/null 2>&1; then
  # macOS with GNU date
  MICROSECONDS=$(gdate +%N 2>/dev/null || echo "$(date +%s)$$")
elif [ -f /proc/uptime ]; then
  # Linux - use microseconds from uptime
  MICROSECONDS=$(awk '{print int($1*1000000)}' /proc/uptime 2>/dev/null || echo "$$")
else
  # Fallback: use process ID and timestamp
  MICROSECONDS="$$$(date +%s)"
fi

# Generate sequence from microseconds (last 3 digits)
SEQ=$(echo "$MICROSECONDS" | tail -c 4 | sed 's/[^0-9]//g')
if [ -z "$SEQ" ] || [ ${#SEQ} -lt 3 ]; then
  # Fallback: use process ID
  SEQ=$(printf "%03d" $(( $$ % 1000 )))
else
  SEQ=$(printf "%03d" $(( 10#$SEQ % 1000 )))
fi

# Ensure SEQ is 3 digits
SEQ=$(printf "%03d" $(( 10#$SEQ % 1000 )))

echo "corr-${DATE_PART}-${SEQ}"
