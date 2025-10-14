#!/usr/bin/env bash
# Autosave Dashboard - สรุปตาม hash → run_id ล่าสุด
# Usage: bash g/tools/autosave_dashboard.sh [--json|--html]

set -euo pipefail

DIR="g/reports/memory_autosave"
OUTPUT_FORMAT="${1:---text}"

# Parse autosave files (new format only)
declare -A hash_info
declare -A hash_count

while IFS= read -r -d '' f; do
  base="$(basename "$f")"

  # Parse: autosave_YYYYmmdd_HHMMSS_<HASH>_<RUNID>.md
  if [[ "$base" =~ autosave_([0-9]{8})_([0-9]{6})_([0-9a-f]{64})_(.+)\.md ]]; then
    date="${BASH_REMATCH[1]}"
    time="${BASH_REMATCH[2]}"
    hash="${BASH_REMATCH[3]}"
    runid="${BASH_REMATCH[4]}"
    ts="$date-$time"

    # Count occurrences per hash
    if [ -z "${hash_count[$hash]+x}" ]; then
      hash_count[$hash]=1
    else
      hash_count[$hash]=$((${hash_count[$hash]} + 1))
    fi

    # Keep latest info per hash
    if [ -z "${hash_info[$hash]+x}" ]; then
      hash_info[$hash]="$ts|$runid|$f"
    else
      old_ts="$(echo "${hash_info[$hash]}" | cut -d'|' -f1)"
      if [[ "$ts" > "$old_ts" ]]; then
        hash_info[$hash]="$ts|$runid|$f"
      fi
    fi
  fi
done < <(find "$DIR" -maxdepth 1 -type f -name "autosave_*.md" -print0)

# Output
if [ "$OUTPUT_FORMAT" = "--json" ]; then
  echo "{"
  echo '  "generated_at": "'$(date -Iseconds)'",'
  echo '  "total_hashes": '${#hash_info[@]}','
  echo '  "autosaves": ['

  first=true
  for hash in "${!hash_info[@]}"; do
    info="${hash_info[$hash]}"
    ts="$(echo "$info" | cut -d'|' -f1)"
    runid="$(echo "$info" | cut -d'|' -f2)"
    file="$(echo "$info" | cut -d'|' -f3)"
    count="${hash_count[$hash]}"

    [ "$first" = false ] && echo ","
    first=false

    cat <<EOF
    {
      "hash": "$hash",
      "hash_short": "${hash:0:12}",
      "timestamp": "$ts",
      "run_id": "$runid",
      "count": $count,
      "file": "$file"
    }
EOF
  done

  echo ""
  echo "  ]"
  echo "}"

elif [ "$OUTPUT_FORMAT" = "--html" ]; then
  cat <<'HTML'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Autosave Dashboard</title>
  <style>
    body { font-family: system-ui; margin: 2rem; background: #f5f5f5; }
    h1 { color: #333; }
    .stats { background: white; padding: 1rem; border-radius: 8px; margin-bottom: 1rem; }
    table { width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; }
    th, td { padding: 0.75rem; text-align: left; border-bottom: 1px solid #eee; }
    th { background: #4CAF50; color: white; }
    tr:hover { background: #f9f9f9; }
    .hash-short { font-family: monospace; background: #eee; padding: 2px 6px; border-radius: 4px; }
    .count { background: #2196F3; color: white; padding: 2px 8px; border-radius: 12px; font-size: 0.85em; }
  </style>
</head>
<body>
  <h1>🗄️ Autosave Dashboard</h1>
  <div class="stats">
    <strong>Generated:</strong> $(date) |
    <strong>Total unique content:</strong> ${#hash_info[@]} hashes
  </div>
  <table>
    <tr>
      <th>Hash (short)</th>
      <th>Timestamp</th>
      <th>Run ID</th>
      <th>Count</th>
      <th>File</th>
    </tr>
HTML

  for hash in $(printf '%s\n' "${!hash_info[@]}" | sort); do
    info="${hash_info[$hash]}"
    ts="$(echo "$info" | cut -d'|' -f1)"
    runid="$(echo "$info" | cut -d'|' -f2)"
    file="$(echo "$info" | cut -d'|' -f3 | xargs basename)"
    count="${hash_count[$hash]}"
    hash_short="${hash:0:12}"

    cat <<EOF
    <tr>
      <td><span class="hash-short">$hash_short</span></td>
      <td>$ts</td>
      <td><code>$runid</code></td>
      <td><span class="count">$count</span></td>
      <td>$file</td>
    </tr>
EOF
  done

  cat <<'HTML'
  </table>
</body>
</html>
HTML

else
  # Text format (default)
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "         🗄️  AUTOSAVE DASHBOARD"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Generated: $(date)"
  echo "Total unique content: ${#hash_info[@]} hashes"
  echo ""
  printf "%-14s %-17s %-20s %6s  %s\n" "HASH (short)" "TIMESTAMP" "RUN_ID" "COUNT" "FILE"
  echo "────────────────────────────────────────────────────────────────────────────────"

  for hash in $(printf '%s\n' "${!hash_info[@]}" | sort); do
    info="${hash_info[$hash]}"
    ts="$(echo "$info" | cut -d'|' -f1)"
    runid="$(echo "$info" | cut -d'|' -f2)"
    file="$(echo "$info" | cut -d'|' -f3 | xargs basename)"
    count="${hash_count[$hash]}"
    hash_short="${hash:0:12}"

    printf "%-14s %-17s %-20s %6s  %s\n" "$hash_short" "$ts" "$runid" "$count" "$file"
  done

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
