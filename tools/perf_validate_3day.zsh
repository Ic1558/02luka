#!/usr/bin/env zsh
# 3-Day Performance Validation Script
# Analyzes collected data and generates summary

set -euo pipefail

LUKA_ROOT="${LUKA_ROOT:-$HOME/02luka}"
LOG_FILE="${LUKA_ROOT}/g/logs/perf_observation_log.md"
SUMMARY_FILE="${LUKA_ROOT}/g/reports/system/perf_validation_summary_$(date '+%Y%m%d').md"
START_DATE="2025-12-09"

main() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "❌ Log file not found: $LOG_FILE"
        exit 1
    fi
    
    echo "📊 Analyzing 3-day performance data..."
    echo ""
    
    # Calculate days since start
    local days_since_start=$(python3 -c "
from datetime import datetime
start = datetime.strptime('$START_DATE', '%Y-%m-%d')
today = datetime.now()
diff = (today - start).days
print(diff)
" 2>/dev/null || echo "0")
    
    if (( days_since_start < 3 )); then
        echo "⏳ Only $days_since_start day(s) have passed. Need 3 days for validation."
        echo "   Run again after Day 3 (2025-12-11)"
        exit 0
    fi
    
    # Extract and analyze data
    python3 <<PYTHON
import re
from datetime import datetime
from statistics import mean, median

log_file = "$LOG_FILE"
summary_file = "$SUMMARY_FILE"
start_date = "$START_DATE"

with open(log_file, 'r') as f:
    content = f.read()

# Extract RAM data for each day
cursor_ram_by_day = {}
ag_ram_by_day = {}
total_ram_by_day = {}

for day in [1, 2, 3]:
    day_pattern = rf"## 🗓️ Day {day}.*?\n(.*?)(?=\n## |$)"
    day_match = re.search(day_pattern, content, re.DOTALL)
    
    if day_match:
        day_content = day_match.group(1)
        # Extract table rows
        rows = re.findall(r'\| (\d{2}:\d{2}) \| (Cursor|Antigravity|\*\*TOTAL\*\*) .*? \| ([\d.]+) \|', day_content)
        
        cursor_rams = []
        ag_rams = []
        total_rams = []
        
        for row in rows:
            time_str, app, ram_str = row
            try:
                ram = float(ram_str)
                if app == "Cursor":
                    cursor_rams.append(ram)
                elif app == "Antigravity":
                    ag_rams.append(ram)
                elif "TOTAL" in app:
                    total_rams.append(ram)
            except:
                pass
        
        if cursor_rams:
            cursor_ram_by_day[day] = {
                'avg': mean(cursor_rams),
                'max': max(cursor_rams),
                'min': min(cursor_rams),
                'count': len(cursor_rams)
            }
        
        if ag_rams:
            ag_ram_by_day[day] = {
                'avg': mean(ag_rams),
                'max': max(ag_rams),
                'min': min(ag_rams),
                'count': len(ag_rams)
            }
        
        if total_rams:
            total_ram_by_day[day] = {
                'avg': mean(total_rams),
                'max': max(total_rams),
                'min': min(total_rams),
                'count': len(total_rams)
            }

# Generate summary
summary = f"""# 📊 Performance Validation Summary

**Validation Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Monitoring Period:** {start_date} to {datetime.now().strftime('%Y-%m-%d')}  
**Duration:** 3 Days

---

## 📈 RAM Usage Analysis

### Cursor

"""
for day in [1, 2, 3]:
    if day in cursor_ram_by_day:
        data = cursor_ram_by_day[day]
        summary += f"**Day {day}:**\n"
        summary += f"- Average: {data['avg']:.2f} GB\n"
        summary += f"- Max: {data['max']:.2f} GB\n"
        summary += f"- Min: {data['min']:.2f} GB\n"
        summary += f"- Samples: {data['count']}\n\n"

if len(cursor_ram_by_day) >= 2:
    day1_avg = cursor_ram_by_day[1]['avg'] if 1 in cursor_ram_by_day else 0
    day3_avg = cursor_ram_by_day[3]['avg'] if 3 in cursor_ram_by_day else 0
    if day1_avg > 0:
        change_pct = ((day3_avg - day1_avg) / day1_avg) * 100
        summary += f"**Trend:** Day 1 → Day 3: {change_pct:+.1f}%\n\n"

summary += "\n### Antigravity\n\n"
for day in [1, 2, 3]:
    if day in ag_ram_by_day:
        data = ag_ram_by_day[day]
        summary += f"**Day {day}:**\n"
        summary += f"- Average: {data['avg']:.2f} GB\n"
        summary += f"- Max: {data['max']:.2f} GB\n"
        summary += f"- Min: {data['min']:.2f} GB\n"
        summary += f"- Samples: {data['count']}\n\n"

if len(ag_ram_by_day) >= 2:
    day1_avg = ag_ram_by_day[1]['avg'] if 1 in ag_ram_by_day else 0
    day3_avg = ag_ram_by_day[3]['avg'] if 3 in ag_ram_by_day else 0
    if day1_avg > 0:
        change_pct = ((day3_avg - day1_avg) / day1_avg) * 100
        summary += f"**Trend:** Day 1 → Day 3: {change_pct:+.1f}%\n\n"

summary += "\n### Total (Cursor + Antigravity)\n\n"
for day in [1, 2, 3]:
    if day in total_ram_by_day:
        data = total_ram_by_day[day]
        summary += f"**Day {day}:**\n"
        summary += f"- Average: {data['avg']:.2f} GB\n"
        summary += f"- Max: {data['max']:.2f} GB\n"
        summary += f"- Min: {data['min']:.2f} GB\n"
        summary += f"- Samples: {data['count']}\n\n"

# Overall assessment
summary += "\n---\n\n## ✅ Validation Results\n\n"

# Check against baseline expectations
baseline_expected = 2.0  # Expected baseline before tuning
target_reduction = 0.30  # 30% reduction target

if total_ram_by_day:
    day1_avg = total_ram_by_day[1]['avg'] if 1 in total_ram_by_day else baseline_expected
    day3_avg = total_ram_by_day[3]['avg'] if 3 in total_ram_by_day else day1_avg
    
    reduction = ((baseline_expected - day3_avg) / baseline_expected) * 100 if baseline_expected > 0 else 0
    
    summary += f"**Baseline (Expected):** {baseline_expected:.2f} GB\n"
    summary += f"**Day 3 Average:** {day3_avg:.2f} GB\n"
    summary += f"**Reduction:** {reduction:.1f}%\n\n"
    
    if reduction >= (target_reduction * 100):
        summary += "✅ **Target Achieved:** RAM reduction ≥30%\n\n"
    elif reduction > 0:
        summary += f"⚠️ **Partial Success:** RAM reduced by {reduction:.1f}% (target: 30%)\n\n"
    else:
        summary += "❌ **Target Not Met:** RAM usage increased or unchanged\n\n"

summary += "\n## 📝 Recommendations\n\n"
summary += "- Review manual notes in observation log\n"
summary += "- Check for stability issues (freezes, crashes)\n"
summary += "- Verify IntelliSense performance\n"
summary += "- Consider additional tuning if needed\n"

summary += f"\n---\n\n**Full Log:** `{log_file}`\n"

with open(summary_file, 'w') as f:
    f.write(summary)

print("✅ Validation complete!")
print(f"   Summary: {summary_file}")
PYTHON
    
    echo ""
    echo "📄 Summary file created:"
    echo "   $SUMMARY_FILE"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Review the summary"
    echo "   2. Check manual notes in observation log"
    echo "   3. Proceed to P1 (HOWTO_TWO_WORLDS.md) if validation passes"
}

main "$@"
