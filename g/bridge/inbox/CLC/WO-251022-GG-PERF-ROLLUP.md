# WO: Nightly Performance Rollup
- **ID:** WO-251022-GG-PERF-ROLLUP
- **Goal:** Daily aggregation of query_perf.jsonl → p50/p95/p99 per pattern, slow-query alerts

## Deliverables

### 1. knowledge/perf_rollup.cjs
- Reads `g/reports/query_perf.jsonl` (one day's worth)
- Groups by query pattern (normalize whitespace, lowercase)
- Compute p50, p95, p99 per pattern
- Flag patterns where p95 > 100ms
- Write `g/reports/query_perf_daily_YYYYMMDD.json`

**Code Skeleton:**
```js
import fs from 'fs';
import path from 'path';

function quantile(arr, q) {
  if (!arr.length) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const pos = (sorted.length - 1) * q;
  const base = Math.floor(pos);
  const rest = pos - base;
  return sorted[base] + (sorted[base + 1] - (sorted[base] || 0)) * (isNaN(rest) ? 0 : rest);
}

function normalizeQuery(q) {
  return q.toLowerCase().replace(/\s+/g, ' ').trim();
}

const lines = fs.readFileSync('g/reports/query_perf.jsonl', 'utf8')
  .split('\n').filter(Boolean);

const byPattern = {};
for (const line of lines) {
  const entry = JSON.parse(line);
  const pattern = normalizeQuery(entry.query || '');
  if (!byPattern[pattern]) byPattern[pattern] = [];
  byPattern[pattern].push(entry.duration_ms || 0);
}

const patterns = Object.entries(byPattern)
  .map(([pattern, durations]) => ({
    pattern,
    samples: durations.length,
    p50: quantile(durations, 0.5),
    p95: quantile(durations, 0.95),
    p99: quantile(durations, 0.99),
    slow: quantile(durations, 0.95) > 100
  }))
  .sort((a, b) => b.p95 - a.p95);

const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
const report = {
  date: today,
  total_queries: lines.length,
  patterns: patterns.slice(0, 20), // Top 20
  slow_patterns: patterns.filter(p => p.slow)
};

fs.writeFileSync(`g/reports/query_perf_daily_${today}.json`, JSON.stringify(report, null, 2));
console.log(`✅ Daily perf rollup → g/reports/query_perf_daily_${today}.json`);
```

### 2. LaunchAgent: ~/Library/LaunchAgents/com.02luka.perfrollup.plist
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.02luka.perfrollup</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/knowledge/perf_rollup.cjs</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>2</integer>
    <key>Minute</key>
    <integer>30</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>/tmp/perfrollup.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/perfrollup.err</string>

  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
```

**Install:**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.perfrollup.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.02luka.perfrollup.plist
launchctl list | grep perfrollup
```

## Acceptance
- Daily rollup runs at 02:30 Asia/Bangkok
- Top 20 patterns by p95 latency
- Slow patterns (p95 > 100ms) flagged
- Output: `g/reports/query_perf_daily_YYYYMMDD.json`
- Zero crashes, reliable execution
