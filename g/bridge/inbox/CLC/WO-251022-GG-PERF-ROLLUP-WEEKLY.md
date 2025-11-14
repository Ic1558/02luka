# WO: Weekly Performance Rollup
- **ID:** WO-251022-GG-PERF-ROLLUP-WEEKLY
- **Goal:** Weekly aggregation (7 days) → top slow patterns, top frequent patterns, full report

## Deliverables

### 1. knowledge/perf_rollup_weekly.cjs
- Reads last 7 `query_perf_daily_*.json` files
- Aggregates patterns across week
- Compute weekly p50/p95/p99
- Generate top 10 slow (by p95), top 10 frequent (by samples)
- Write `g/reports/query_perf_weekly_YYYYWW.json`

**Code Skeleton:**
```js
import fs from 'fs';
import path from 'path';

function getISOWeek(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + 4 - (d.getDay() || 7));
  const yearStart = new Date(d.getFullYear(), 0, 1);
  return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
}

function quantile(arr, q) {
  if (!arr.length) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const pos = (sorted.length - 1) * q;
  const base = Math.floor(pos);
  const rest = pos - base;
  return sorted[base] + (sorted[base + 1] - (sorted[base] || 0)) * (isNaN(rest) ? 0 : rest);
}

const reportsDir = 'g/reports';
const files = fs.readdirSync(reportsDir)
  .filter(f => f.startsWith('query_perf_daily_') && f.endsWith('.json'))
  .sort()
  .slice(-7); // Last 7 days

const allPatterns = {};
for (const file of files) {
  const daily = JSON.parse(fs.readFileSync(path.join(reportsDir, file), 'utf8'));
  for (const pattern of daily.patterns) {
    if (!allPatterns[pattern.pattern]) {
      allPatterns[pattern.pattern] = { samples: 0, p95s: [], p99s: [] };
    }
    allPatterns[pattern.pattern].samples += pattern.samples;
    allPatterns[pattern.pattern].p95s.push(pattern.p95);
    allPatterns[pattern.pattern].p99s.push(pattern.p99);
  }
}

const weeklyPatterns = Object.entries(allPatterns).map(([pattern, data]) => ({
  pattern,
  samples: data.samples,
  p50_weekly: quantile(data.p95s, 0.5),
  p95_weekly: quantile(data.p95s, 0.95),
  p99_weekly: quantile(data.p99s, 0.99)
}));

const topSlow = [...weeklyPatterns].sort((a, b) => b.p95_weekly - a.p95_weekly).slice(0, 10);
const topFrequent = [...weeklyPatterns].sort((a, b) => b.samples - a.samples).slice(0, 10);

const today = new Date();
const year = today.getFullYear();
const week = getISOWeek(today);
const weekId = `${year}${String(week).padStart(2, '0')}`;

const report = {
  week: weekId,
  days_covered: files.length,
  total_patterns: weeklyPatterns.length,
  top_slow_by_p95: topSlow,
  top_frequent_by_samples: topFrequent,
  all_patterns: weeklyPatterns
};

fs.writeFileSync(`g/reports/query_perf_weekly_${weekId}.json`, JSON.stringify(report, null, 2));
console.log(`✅ Weekly perf rollup → g/reports/query_perf_weekly_${weekId}.json`);
```

### 2. LaunchAgent: ~/Library/LaunchAgents/com.02luka.perfrollup.weekly.plist
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.02luka.perfrollup.weekly</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/knowledge/perf_rollup_weekly.cjs</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>0</integer>
    <key>Hour</key>
    <integer>3</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>/tmp/perfrollup_weekly.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/perfrollup_weekly.err</string>

  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
```

**Install:**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.perfrollup.weekly.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.02luka.perfrollup.weekly.plist
launchctl list | grep perfrollup
```

## Acceptance
- Weekly rollup runs Sundays at 03:00 Asia/Bangkok
- Aggregates last 7 daily files
- Top 10 slow patterns (by p95_weekly)
- Top 10 frequent patterns (by samples)
- Output: `g/reports/query_perf_weekly_YYYYWW.json` (ISO week format)
- Zero crashes, reliable execution
