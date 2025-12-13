#!/usr/bin/env zsh
# Daily Performance Collection Script
# Collects RAM usage, basic metrics for Antigravity & Cursor
# Auto-appends to perf_observation_log.md

set -euo pipefail

LUKA_ROOT="${LUKA_ROOT:-$HOME/02luka}"
LOG_FILE="${LUKA_ROOT}/g/logs/perf_observation_log.md"
TODAY=$(date '+%Y-%m-%d')
NOW=$(date '+%H:%M')

# Get RAM usage for IDE processes
get_ide_ram() {
    local app_name="$1"
    ps aux | grep -i "$app_name" | grep -v grep | awk '{sum+=$6} END {if (sum) print sum/1024/1024; else print "0"}'
}

# Get total RAM usage
get_total_ram() {
    local cursor_ram=$(get_ide_ram "Cursor")
    local ag_ram=$(get_ide_ram "Antigravity")
    local total=$(echo "$cursor_ram + $ag_ram" | bc -l 2>/dev/null || echo "0")
    printf "%.2f" "$total"
}

# Check if process is running
is_running() {
    local app_name="$1"
    pgrep -f -i "$app_name" >/dev/null 2>&1
}

# Main collection
main() {
    local cursor_ram=$(get_ide_ram "Cursor")
    local ag_ram=$(get_ide_ram "Antigravity")
    local total_ram=$(get_total_ram)
    
    local cursor_running=""
    local ag_running=""
    
    if is_running "Cursor"; then
        cursor_running="✅"
    else
        cursor_running="❌"
        cursor_ram="0"
    fi
    
    if is_running "Antigravity"; then
        ag_running="✅"
    else
        ag_running="❌"
        ag_ram="0"
    fi
    
    # Determine which day we're on (Day 1, 2, or 3)
    local start_date="2025-12-09"
    local day_num=$(python3 -c "
from datetime import datetime
start = datetime.strptime('$start_date', '%Y-%m-%d')
today = datetime.strptime('$TODAY', '%Y-%m-%d')
diff = (today - start).days + 1
print(min(max(diff, 1), 3))
" 2>/dev/null || echo "1")
    
    # Find the Day section and append entry
    if [[ -f "$LOG_FILE" ]]; then
        # Create temp file for safe editing
        local temp_file=$(mktemp)
        
        # Use Python to safely insert the entry
        python3 <<PYTHON
import re
from datetime import datetime

log_file = "$LOG_FILE"
temp_file = "$temp_file"
now = "$NOW"
cursor_ram = "$cursor_ram"
ag_ram = "$ag_ram"
total_ram = "$total_ram"
cursor_running = "$cursor_running"
ag_running = "$ag_running"
day_num = int("$day_num")

with open(log_file, 'r') as f:
    content = f.read()

# Find Day section
day_pattern = rf"## 🗓️ Day {day_num} \(.*?\)"
day_match = re.search(day_pattern, content)

if day_match:
    # Find the table in this day section
    day_start = day_match.end()
    # Find next ## section or end of file
    next_section = re.search(r'\n## ', content[day_start:])
    if next_section:
        day_end = day_start + next_section.start()
    else:
        day_end = len(content)
    
    day_content = content[day_start:day_end]
    
    # Find separator line and insert after it
    sep_pattern = r'(\| :---.*?\n)'
    sep_match = re.search(sep_pattern, day_content)
    
    if sep_match:
        sep_pos = sep_match.end()
        
        # Build new row
        cursor_ram_float = float(cursor_ram)
        ag_ram_float = float(ag_ram)
        total_ram_str = str(total_ram)
        new_row_formatted = f"| {now} | Cursor {cursor_running} | {cursor_ram_float:.2f} | (manual) | (manual) |\n"
        new_row_formatted += f"| {now} | Antigravity {ag_running} | {ag_ram_float:.2f} | (manual) | (manual) |\n"
        new_row_formatted += f"| {now} | **TOTAL** | **{total_ram_str}** | - | - |\n"
        
        # Find where to insert (after separator, before next section)
        next_section = re.search(r'\n\*\*Day', day_content[sep_pos:])
        if next_section:
            insert_pos = sep_pos + next_section.start()
        else:
            insert_pos = len(day_content)
        
        # Remove any existing empty rows near separator
        after_sep = day_content[sep_pos:insert_pos]
        after_sep_clean = re.sub(r'^\|[\s|]+\|\s*\n', '', after_sep, flags=re.MULTILINE)
        
        # Insert new rows
        new_day_content = (
            day_content[:sep_pos] +
            after_sep_clean +
            new_row_formatted +
            day_content[insert_pos:]
        )
        
        new_content = content[:day_start] + new_day_content + content[day_end:]
    else:
        # Table not found, append at end of day section
        cursor_ram_float = float(cursor_ram)
        ag_ram_float = float(ag_ram)
        total_ram_str = str(total_ram)
        new_row = f"\n| {now} | Cursor {cursor_running} | {cursor_ram_float:.2f} | (manual) | (manual) |\n"
        new_row += f"| {now} | Antigravity {ag_running} | {ag_ram_float:.2f} | (manual) | (manual) |\n"
        new_row += f"| {now} | **TOTAL** | **{total_ram_str}** | - | - |\n"
        new_content = content[:day_end] + new_row + content[day_end:]
else:
    # Day section not found, append to end
    cursor_ram_float = float(cursor_ram)
    ag_ram_float = float(ag_ram)
    total_ram_str = str(total_ram)
    new_row = f"\n## 🗓️ Day {day_num} ({day_num})\n\n"
    new_row += f"| Time | App | RAM (GB) | Feel (1-10) | Context |\n"
    new_row += f"| :--- | :--- | :--- | :--- | :--- |\n"
    new_row += f"| {now} | Cursor {cursor_running} | {cursor_ram_float:.2f} | (manual) | (manual) |\n"
    new_row += f"| {now} | Antigravity {ag_running} | {ag_ram_float:.2f} | (manual) | (manual) |\n"
    new_row += f"| {now} | **TOTAL** | **{total_ram_str}** | - | - |\n"
    new_content = content + new_row

with open(temp_file, 'w') as f:
    f.write(new_content)
PYTHON
        
        # Atomic move
        mv "$temp_file" "$LOG_FILE"
        
        echo "✅ Performance data collected:"
        echo "   Time: $NOW"
        echo "   Cursor: ${cursor_ram} GB $cursor_running"
        echo "   Antigravity: ${ag_ram} GB $ag_running"
        echo "   Total: ${total_ram} GB"
        echo "   → Appended to Day $day_num"
    else
        echo "⚠️ Log file not found: $LOG_FILE"
        exit 1
    fi
}

main "$@"
