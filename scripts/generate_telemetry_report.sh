#!/usr/bin/env bash
# Generate telemetry report for last 24 hours
# Outputs to g/reports/telemetry_last24h.md

set -euo pipefail

# Source universal path resolver
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/repo_root_resolver.sh"

# Output file
OUTPUT_FILE="$REPO_ROOT/g/reports/telemetry_last24h.md"

# Get telemetry summary
if ! command -v node >/dev/null 2>&1; then
  echo "Error: node is required to generate telemetry report" >&2
  exit 1
fi

# Generate summary JSON to temp file
SUMMARY_FILE=$(mktemp)
trap "rm -f $SUMMARY_FILE" EXIT
node "$REPO_ROOT/boss-api/telemetry.cjs" --summary > "$SUMMARY_FILE"

# Parse summary JSON using jq (or python if jq not available)
if command -v jq >/dev/null 2>&1; then
  total_runs=$(jq -r '.total_runs' "$SUMMARY_FILE")
  total_pass=$(jq -r '.total_pass' "$SUMMARY_FILE")
  total_warn=$(jq -r '.total_warn' "$SUMMARY_FILE")
  total_fail=$(jq -r '.total_fail' "$SUMMARY_FILE")
  total_duration=$(jq -r '.total_duration_ms' "$SUMMARY_FILE")
  period_since=$(jq -r '.period.since' "$SUMMARY_FILE")
  period_until=$(jq -r '.period.until' "$SUMMARY_FILE")
else
  total_runs=$(python3 -c "import sys, json; print(json.load(open('$SUMMARY_FILE'))['total_runs'])")
  total_pass=$(python3 -c "import sys, json; print(json.load(open('$SUMMARY_FILE'))['total_pass'])")
  total_warn=$(python3 -c "import sys, json; print(json.load(open('$SUMMARY_FILE'))['total_warn'])")
  total_fail=$(python3 -c "import sys, json; print(json.load(open('$SUMMARY_FILE'))['total_fail'])")
  total_duration=$(python3 -c "import sys, json; print(json.load(open('$SUMMARY_FILE'))['total_duration_ms'])")
  period_since=$(python3 -c "import sys, json; print(json.load(open('$SUMMARY_FILE'))['period']['since'])")
  period_until=$(python3 -c "import sys, json; print(json.load(open('$SUMMARY_FILE'))['period']['until'])")
fi

# Calculate average duration
if [ "$total_runs" -gt 0 ]; then
  avg_duration=$((total_duration / total_runs))
else
  avg_duration=0
fi

# Generate markdown report
cat > "$OUTPUT_FILE" <<EOF
# Telemetry Report — Last 24 Hours

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Period:** $period_since to $period_until

## Summary

| Metric | Value |
| ------ | ----- |
| Total Runs | $total_runs |
| Total Pass | $total_pass |
| Total Warn | $total_warn |
| Total Fail | $total_fail |
| Total Duration | ${total_duration}ms |
| Avg Duration | ${avg_duration}ms |

## By Task

EOF

# Add task breakdown
python3 - "$SUMMARY_FILE" <<'PYTHON' >> "$OUTPUT_FILE"
import sys, json

with open(sys.argv[1], 'r') as f:
    data = json.load(f)
by_task = data.get('by_task', {})

if not by_task:
    print("_No task data available._")
    sys.exit(0)

print("| Task | Runs | Pass | Warn | Fail | Avg Duration |")
print("| ---- | ---- | ---- | ---- | ---- | ------------ |")

for task, stats in sorted(by_task.items()):
    runs = stats['runs']
    pass_count = stats['pass']
    warn_count = stats['warn']
    fail_count = stats['fail']
    total_ms = stats['duration_ms']
    avg_ms = total_ms // runs if runs > 0 else 0
    print(f"| {task} | {runs} | {pass_count} | {warn_count} | {fail_count} | {avg_ms}ms |")
PYTHON

# Add raw telemetry data section
cat >> "$OUTPUT_FILE" <<'EOF'

## Recent Runs (Last 10)

EOF

# Get last 10 entries
python3 - "$REPO_ROOT" <<'PYTHON' >> "$OUTPUT_FILE"
import sys, json, os
from datetime import datetime

repo_root = sys.argv[1]

# We need to read the actual log files to get individual entries
# For simplicity, just read recent entries from telemetry module

telemetry_dir = os.path.join(repo_root, 'g', 'telemetry')
if not os.path.exists(telemetry_dir):
    print("_No telemetry data available._")
    sys.exit(0)

# Get all log files
import glob
log_files = sorted(glob.glob(os.path.join(telemetry_dir, '*.log')), reverse=True)

entries = []
for log_file in log_files[:3]:  # Read last 3 days max
    with open(log_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                entries.append(entry)
            except:
                pass

# Sort by timestamp descending and take last 10
entries.sort(key=lambda x: x.get('ts', ''), reverse=True)
entries = entries[:10]

if not entries:
    print("_No recent runs found._")
    sys.exit(0)

print("| Timestamp | Task | Pass | Warn | Fail | Duration |")
print("| --------- | ---- | ---- | ---- | ---- | -------- |")

for entry in entries:
    ts = entry.get('ts', 'N/A')
    # Format timestamp
    try:
        dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
        ts_display = dt.strftime('%Y-%m-%d %H:%M:%S')
    except:
        ts_display = ts[:19] if len(ts) >= 19 else ts

    task = entry.get('task', 'unknown')
    pass_count = entry.get('pass', 0)
    warn_count = entry.get('warn', 0)
    fail_count = entry.get('fail', 0)
    duration = entry.get('duration_ms', 0)

    print(f"| {ts_display} | {task} | {pass_count} | {warn_count} | {fail_count} | {duration}ms |")
PYTHON

echo ""
echo "Telemetry report generated: $OUTPUT_FILE"
