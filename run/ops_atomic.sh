#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="${1:-"$SCRIPT_DIR/../g/reports"}"

if [[ ! -d "$REPORTS_DIR" ]]; then
  echo "Reports directory not found: $REPORTS_DIR" >&2
  exit 1
fi

# Delete OPS_ATOMIC_*.md files older than 30 days.
find "$REPORTS_DIR" -type f -name 'OPS_ATOMIC_*.md' -mtime +30 -print0 \
  | xargs -0 -r rm -f

# Retain only the most recent OPS_SUMMARY*.json file if multiple exist.
mapfile -t _ops_summaries < <(find "$REPORTS_DIR" -type f -name 'OPS_SUMMARY*.json' -print0 \
  | xargs -0 -r -I{} bash -c '
      file="$1"
      if stat -c %Y "$file" >/dev/null 2>&1; then
        mtime=$(stat -c %Y "$file")
      else
        mtime=$(stat -f %m "$file")
      fi
      printf "%s::%s\n" "$mtime" "$file"
    ' _ {})

if (( ${#_ops_summaries[@]} > 1 )); then
  IFS=$'\n' read -r -d '' -a sorted < <(printf '%s\n' "${_ops_summaries[@]}" | sort -r && printf '\0')
  for entry in "${sorted[@]:1}"; do
    file="${entry#*::}"
    rm -f "$file"
  done
fi
