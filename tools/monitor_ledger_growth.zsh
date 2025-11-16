#!/usr/bin/env zsh
# Monitor Ledger File Growth
# Tracks ledger file sizes and growth rates

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
LEDGER_DIR="$REPO_ROOT/g/ledger"
REPORT_FILE="${1:-g/reports/ledger_monitoring/$(date +%Y%m%d_%H%M%S).txt}"

mkdir -p "$(dirname "$REPORT_FILE")"

echo "📊 Ledger File Growth Monitor"
echo "============================"
echo "Report: $REPORT_FILE"
echo ""

{
  echo "Ledger Growth Report - $(date -Iseconds)"
  echo "========================================"
  echo ""
  
  # Check each agent's ledger
  for agent_dir in "$LEDGER_DIR"/*/; do
    agent=$(basename "$agent_dir")
    echo "Agent: $agent"
    echo "-------------------"
    
    # Find all ledger files
    total_files=0
    total_size=0
    largest_file=""
    largest_size=0
    
    while IFS= read -r file; do
      if [[ -f "$file" ]]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        lines=$(wc -l < "$file" 2>/dev/null || echo "0")
        
        ((total_files++))
        total_size=$((total_size + size))
        
        if [[ $size -gt $largest_size ]]; then
          largest_size=$size
          largest_file=$(basename "$file")
        fi
        
        echo "  $(basename "$file"): ${size} bytes, ${lines} lines"
      fi
    done < <(find "$agent_dir" -name "*.jsonl" -type f 2>/dev/null | sort)
    
    if [[ $total_files -gt 0 ]]; then
      echo ""
      echo "  Total files: $total_files"
      echo "  Total size: $total_size bytes ($(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "${total_size}B"))"
      echo "  Largest file: $largest_file ($(numfmt --to=iec-i --suffix=B $largest_size 2>/dev/null || echo "${largest_size}B"))"
      echo "  Average size: $((total_size / total_files)) bytes"
    else
      echo "  No ledger files found"
    fi
    echo ""
  done
  
  # Check status files
  echo "Status Files"
  echo "-------------------"
  for agent in cls andy hybrid gg; do
    status_file="$REPO_ROOT/agents/$agent/status.json"
    if [[ -f "$status_file" ]]; then
      size=$(stat -f%z "$status_file" 2>/dev/null || stat -c%s "$status_file" 2>/dev/null || echo "0")
      state=$(jq -r '.state // "unknown"' "$status_file" 2>/dev/null || echo "unknown")
      last_heartbeat=$(jq -r '.last_heartbeat // "unknown"' "$status_file" 2>/dev/null || echo "unknown")
      echo "  $agent: ${size} bytes, state=$state, last_heartbeat=$last_heartbeat"
    else
      echo "  $agent: No status file"
    fi
  done
  echo ""
  
  # Growth rate (compare with previous day)
  echo "Growth Analysis"
  echo "-------------------"
  today=$(date '+%Y-%m-%d')
  yesterday=$(date -v-1d '+%Y-%m-%d' 2>/dev/null || date -d '1 day ago' '+%Y-%m-%d' 2>/dev/null || echo "")
  
  if [[ -n "$yesterday" ]]; then
    for agent_dir in "$LEDGER_DIR"/*/; do
      agent=$(basename "$agent_dir")
      today_file="$agent_dir/$today.jsonl"
      yesterday_file="$agent_dir/$yesterday.jsonl"
      
      if [[ -f "$today_file" ]] && [[ -f "$yesterday_file" ]]; then
        today_size=$(stat -f%z "$today_file" 2>/dev/null || stat -c%s "$today_file" 2>/dev/null || echo "0")
        yesterday_size=$(stat -f%z "$yesterday_file" 2>/dev/null || stat -c%s "$yesterday_file" 2>/dev/null || echo "0")
        today_lines=$(wc -l < "$today_file" 2>/dev/null || echo "0")
        yesterday_lines=$(wc -l < "$yesterday_file" 2>/dev/null || echo "0")
        
        size_diff=$((today_size - yesterday_size))
        lines_diff=$((today_lines - yesterday_lines))
        
        echo "  $agent:"
        echo "    Size: +${size_diff} bytes ($(numfmt --to=iec-i --suffix=B $size_diff 2>/dev/null || echo "${size_diff}B"))"
        echo "    Lines: +${lines_diff} entries"
      fi
    done
  else
    echo "  (Growth analysis requires previous day's data)"
  fi
  
} | tee "$REPORT_FILE"

echo ""
echo "✅ Report saved to: $REPORT_FILE"
