const fs = require('fs');
const path = require('path');

// Parse command-line flags
const CSV = process.argv.includes('--csv');

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
  if (sorted.length === 1) return sorted[0];
  const pos = (sorted.length - 1) * q;
  const base = Math.floor(pos);
  const rest = pos - base;
  if (base + 1 >= sorted.length) return sorted[base];
  return sorted[base] + (sorted[base + 1] - sorted[base]) * rest;
}

function toCSV(patterns) {
  const esc = s => `"${String(s).replace(/"/g, '""')}"`;
  const lines = ['pattern,samples,avg_ms,p50_ms,p95_ms,p99_ms,slow_flag'];
  for (const p of patterns) {
    const p50 = p.p50_weekly ?? 0;
    const p95 = p.p95_weekly ?? 0;
    const p99 = p.p99_weekly ?? 0;
    const avg = (p50 + p95 + p99) / 3;
    const slow = p95 > 100;
    lines.push([
      esc(p.pattern),
      p.samples,
      avg.toFixed(2),
      p50.toFixed(2),
      p95.toFixed(2),
      p99.toFixed(2),
      slow ? 'true' : 'false'
    ].join(','));
  }
  return lines.join('\n') + '\n';
}

const reportsDir = 'g/reports';
const files = fs.readdirSync(reportsDir)
  .filter(f => f.startsWith('query_perf_daily_') && f.endsWith('.json'))
  .sort()
  .slice(-7); // Last 7 days

if (files.length === 0) {
  console.log('⚠️  No daily performance files found. Skipping weekly rollup.');
  process.exit(0);
}

const allPatterns = {};
for (const file of files) {
  const daily = JSON.parse(fs.readFileSync(path.join(reportsDir, file), 'utf8'));
  for (const pattern of daily.patterns) {
    if (!allPatterns[pattern.pattern]) {
      allPatterns[pattern.pattern] = { samples: 0, p50s: [], p95s: [], p99s: [] };
    }
    allPatterns[pattern.pattern].samples += pattern.samples;
    allPatterns[pattern.pattern].p50s.push(pattern.p50);
    allPatterns[pattern.pattern].p95s.push(pattern.p95);
    allPatterns[pattern.pattern].p99s.push(pattern.p99);
  }
}

const weeklyPatterns = Object.entries(allPatterns).map(([pattern, data]) => ({
  pattern,
  samples: data.samples,
  p50_weekly: quantile(data.p50s, 0.5),
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

const OUT = `g/reports/query_perf_weekly_${weekId}.json`;
fs.writeFileSync(OUT, JSON.stringify(report, null, 2));
console.log(`✅ Weekly perf rollup → ${OUT}`);

if (CSV) {
  const OUTCSV = OUT.replace(/\.json$/, '.csv');
  fs.writeFileSync(OUTCSV, toCSV(weeklyPatterns));
  console.log(`✅ CSV export → ${OUTCSV}`);
}
