#!/usr/bin/env zsh
set -euo pipefail

# Phase 6.2: Governance Index & Visualization Generator
# Generates JSON index and HTML snapshot for weekly governance reports
# Usage: tools/governance_index_generator.zsh [YYYYMMDD]
#   - Without date: Uses current date (week end)
#   - With date: Uses specified date as week end

REPO="${REPO:-$HOME/02luka}"
cd "$REPO"

# ---- Configuration
RECENT_DIGESTS_LIMIT=7
RECENT_RECAPS_LIMIT=4
INDEX_OUTPUT="g/reports/system/index.json"
HTML_OUTPUT_DIR="g/reports/system"

# ---- Error Handling
log_error() {
  local context="$1"
  local message="$2"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR [$context] $message" >&2
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"level\":\"error\",\"context\":\"$context\",\"message\":\"$message\"}" >> "$REPO/g/telemetry/cls_audit.jsonl" 2>/dev/null || true
}

log_info() {
  local message="$1"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] INFO $message" >&2
}

# ---- Portable mtime (macOS / GNU)
get_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# ---- Find latest file (single file, most recent)
find_latest_file() {
  local pattern="$1"
  local dir="$2"
  local latest_file=""
  
  # Use find with -print0 and sort by mtime, more reliable than glob
  if command -v find >/dev/null 2>&1; then
    # Try find with -printf (GNU) or -print0 + stat (macOS)
    if find "$dir" -maxdepth 1 -name "$pattern" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | read -r latest_file; then
      [[ -n "$latest_file" ]] && echo "$latest_file"
      return
    fi
    # Fallback: use find + ls -t
    latest_file=$(find "$dir" -maxdepth 1 -name "$pattern" -type f -exec ls -1t {} + 2>/dev/null | head -1)
    [[ -n "$latest_file" ]] && echo "$latest_file"
    return
  fi
  
  # Fallback: use glob with ls -t
  setopt null_glob
  latest_file=$(ls -1t "$dir"/$~pattern 2>/dev/null | head -1)
  unsetopt null_glob
  
  [[ -n "$latest_file" ]] && echo "$latest_file" || true
}

# ---- Find recent files and return as JSON array
find_recent_files_json() {
  local pattern="$1"
  local dir="$2"
  local limit="$3"
  local -a arr=()
  
  setopt null_glob
  for f in "$dir"/$~pattern; do
    [[ -f "$f" ]] && arr+=("$f")
  done
  unsetopt null_glob
  
  if (( ${#arr[@]} == 0 )); then
    echo "[]"
    return
  fi
  
  # Sort by mtime descending
  local -a sorted=()
  for f in "${arr[@]}"; do
    local m; m=$(get_mtime "$f")
    sorted+=("$m|$f")
  done
  IFS=$'\n' sorted=($(printf '%s\n' "${sorted[@]}" | sort -rn | cut -d'|' -f2-))
  
  # Limit results safely
  local actual_limit=$(( limit < ${#sorted[@]} ? limit : ${#sorted[@]} ))
  local out="[]"
  for i in {1..$actual_limit}; do
    local f="${sorted[$i]}"
    [[ -z "$f" ]] && continue
    local b="${f:t}"
    local d; d=$(echo "$b" | sed -nE 's/.*([0-9]{8}).*/\1/p')
    if [[ "$d" =~ ^[0-9]{8}$ ]] && date -j -f %Y%m%d "$d" >/dev/null 2>&1; then
      out=$(jq -c --arg d "$d" --arg p "$f" '. + [{"date":$d,"path":$p}]' <<<"$out")
    fi
  done
  echo "$out"
}

# ---- Get adaptive insights summary
insights_summary_json() {
  local latest_insights
  latest_insights=$(find_latest_file "insights_*.json" "mls/adaptive" || true)
  
  if [[ -z "${latest_insights:-}" ]]; then
    jq -n '{
      summary: {
        trends_count: 0,
        anomalies_count: 0,
        recommendations_count: 0,
        last_updated: "never"
      },
      latest_file: null
    }'
    return
  fi
  
  # Read insights file and generate summary (compatible with older jq)
  local trends_count anomalies_count recommendations_count last_updated
  trends_count=$(jq -r '.trends // {} | length' "$latest_insights" 2>/dev/null || echo "0")
  anomalies_count=$(jq -r '.anomalies // [] | length' "$latest_insights" 2>/dev/null || echo "0")
  recommendations_count=$(jq -r '.recommendations // [] | length' "$latest_insights" 2>/dev/null || echo "0")
  last_updated=$(jq -r '.generated_at // .date // "unknown"' "$latest_insights" 2>/dev/null || echo "unknown")
  
  jq -n \
    --arg tc "$trends_count" \
    --arg ac "$anomalies_count" \
    --arg rc "$recommendations_count" \
    --arg lu "$last_updated" \
    --arg lf "$latest_insights" \
    '{
      summary: {
        trends_count: ($tc | tonumber),
        anomalies_count: ($ac | tonumber),
        recommendations_count: ($rc | tonumber),
        last_updated: $lu
      },
      latest_file: $lf
    }'
}

# ---- Atomic JSON write with validation
write_json_atomic() {
  local file="$1"
  local json="$2"
  local tmp
  
  tmp=$(mktemp)
  print -r -- "$json" > "$tmp"
  
  if jq empty "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$file"
    return 0
  fi
  
  rm -f "$tmp"
  log_error "index_generation" "Invalid JSON generated for $file"
  return 1
}

# ---- Generate HTML snapshot
generate_html_snapshot() {
  local week_end="$1"
  local latest_insights
  
  latest_insights=$(find_latest_file "insights_*.json" "mls/adaptive" || true)
  [[ -n "${latest_insights:-}" ]] || return 0
  
  # Check if insights have actual data
  if ! jq -e '.trends != {} or .anomalies != [] or .recommendations != []' "$latest_insights" >/dev/null 2>&1; then
    return 0  # Skip if no data
  fi
  
  local out="$HTML_OUTPUT_DIR/trends_snapshot_${week_end}.html"
  local weekly_recap="system_governance_WEEKLY_${week_end}.md"
  
  # Extract data from insights
  local trends_json anomalies_json recommendations_json summary_text
  trends_json=$(jq -r '.trends // {}' "$latest_insights" 2>/dev/null || echo "{}")
  anomalies_json=$(jq -r '.anomalies // []' "$latest_insights" 2>/dev/null || echo "[]")
  recommendations_json=$(jq -r '.recommendations // []' "$latest_insights" 2>/dev/null || echo "[]")
  summary_text=$(jq -r '.recommendation_summary // "No specific recommendations"' "$latest_insights" 2>/dev/null || echo "No specific recommendations")
  
  # Generate trends table HTML
  local trends_html="<p>No trends detected</p>"
  if [[ "$trends_json" != "{}" ]]; then
    trends_html=$(echo "$trends_json" | jq -r '
      "<table><thead><tr><th>Metric</th><th>Direction</th><th>Change</th></tr></thead><tbody>" +
      (to_entries[] | "<tr><td>\(.key)</td><td><span class=\"badge \(.value.direction // "stable")\">\(.value.direction // "stable" | ascii_upcase)</span></td><td>\(.value.change // "0%")</td></tr>") +
      "</tbody></table>"
    ' 2>/dev/null || echo "<p>Error parsing trends</p>")
  fi
  
  # Generate anomalies HTML
  local anomalies_html="<p>No anomalies detected</p>"
  if [[ "$anomalies_json" != "[]" ]]; then
    anomalies_html=$(echo "$anomalies_json" | jq -r '
      "<ul>" +
      (.[] | "<li><strong>\(.metric // "unknown"):</strong> \(.value // "N/A") (expected: \(.expected // "N/A")) - <span class=\"badge \(.severity // "low")\">\(.severity // "low" | ascii_upcase)</span></li>") +
      "</ul>"
    ' 2>/dev/null || echo "<p>Error parsing anomalies</p>")
  fi
  
  # Generate recommendations HTML
  local recs_html="<p>$summary_text</p>"
  if [[ "$recommendations_json" != "[]" ]] && [[ "$recommendations_json" != "null" ]]; then
    recs_html=$(echo "$recommendations_json" | jq -r '
      "<ul>" +
      (.[] | "<li>\(.)</li>") +
      "</ul>"
    ' 2>/dev/null || echo "<p>$summary_text</p>")
  fi
  
  cat > "$out" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Trend Snapshot - $week_end</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      margin: 0;
      padding: 20px;
      background: #f5f5f5;
      line-height: 1.6;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
      background: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    h1 {
      color: #333;
      border-bottom: 2px solid #4CAF50;
      padding-bottom: 10px;
    }
    h2 {
      color: #555;
      margin-top: 30px;
    }
    .badge {
      display: inline-block;
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 12px;
      font-weight: bold;
    }
    .badge.improving, .badge.up {
      background: #4CAF50;
      color: white;
    }
    .badge.declining, .badge.down {
      background: #f44336;
      color: white;
    }
    .badge.stable {
      background: #9E9E9E;
      color: white;
    }
    .badge.high {
      background: #f44336;
      color: white;
    }
    .badge.medium {
      background: #ff9800;
      color: white;
    }
    .badge.low {
      background: #fffbcc;
      color: #795;
    }
    table {
      border-collapse: collapse;
      width: 100%;
      margin: 20px 0;
    }
    th, td {
      border: 1px solid #ddd;
      padding: 8px;
      text-align: left;
    }
    th {
      background: #f6f6f6;
      font-weight: 600;
    }
    ul {
      margin: 20px 0;
      padding-left: 20px;
    }
    li {
      margin: 8px 0;
    }
    .footer {
      text-align: center;
      color: #666;
      font-size: 12px;
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #ddd;
    }
    a {
      color: #0366d6;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Adaptive Insights Snapshot — $week_end</h1>
    
    <p><a href="$weekly_recap">← Back to Weekly Recap</a></p>
    
    <h2>Trends (Last 7 Days)</h2>
    $trends_html
    
    <h2>Anomalies</h2>
    $anomalies_html
    
    <h2>Recommendations</h2>
    $recs_html
    
    <div class="footer">
      Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")<br>
      Generated by: tools/governance_index_generator.zsh
    </div>
  </div>
</body>
</html>
HTML
  
  log_info "HTML snapshot generated: $out"
}

# ---- Main execution
WEEK_END="${1:-$(date +%Y%m%d)}"

log_info "Generating governance index for week ending $WEEK_END"

# Discover latest files (sequential - fast enough with globs)
latest_digest=$(find_latest_file "memory_digest_*.md" "g/reports/system" || true)
latest_recap=$(find_latest_file "system_governance_WEEKLY_*.md" "g/reports/system" || true)
latest_cert5=$(find_latest_file "DEPLOYMENT_CERTIFICATE_*.md" "g/reports/phase5_governance" || true)
latest_cert6=$(find_latest_file "DEPLOYMENT_CERTIFICATE_*.md" "g/reports/phase6_paula" || true)

# Get recent files
recent_digests=$(find_recent_files_json "memory_digest_*.md" "g/reports/system" "$RECENT_DIGESTS_LIMIT")
recent_recaps=$(find_recent_files_json "system_governance_WEEKLY_*.md" "g/reports/system" "$RECENT_RECAPS_LIMIT")
insights_block=$(insights_summary_json)

# Generate JSON index
json=$(jq -n \
  --arg ld "${latest_digest:-}" \
  --arg lr "${latest_recap:-}" \
  --arg c5 "${latest_cert5:-}" \
  --arg c6 "${latest_cert6:-}" \
  --argjson rd "$recent_digests" \
  --argjson rr "$recent_recaps" \
  --argjson ai "$insights_block" \
  '{
    generated_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    latest: {
      daily_digest: (if $ld == "" then null else $ld end),
      weekly_recap: (if $lr == "" then null else $lr end),
      certificates: {
        phase5: (if $c5 == "" then null else $c5 end),
        phase6: (if $c6 == "" then null else $c6 end)
      }
    },
    recent: {
      daily_digests: $rd,
      weekly_recaps: $rr
    },
    adaptive_insights: $ai,
    metadata: {
      total_daily_digests: ($rd | length),
      total_weekly_recaps: ($rr | length),
      total_certificates: ((if $c5 == "" then 0 else 1 end) + (if $c6 == "" then 0 else 1 end))
    }
  }')

# Write index atomically
if ! write_json_atomic "$INDEX_OUTPUT" "$json"; then
  log_error "index_generation" "Failed to write index JSON"
  exit 1
fi

log_info "Index JSON generated: $INDEX_OUTPUT"

# Generate HTML snapshot (lazy - only if insights exist)
generate_html_snapshot "$WEEK_END"

log_info "Governance index generation complete"

