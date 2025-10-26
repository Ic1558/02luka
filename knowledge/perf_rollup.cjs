const fs = require('fs');
const path = require('path');

// Parse command-line flags
const CSV = process.argv.includes('--csv');

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

function normalizeQuery(q) {
  return q.toLowerCase().replace(/\s+/g, ' ').trim();
}

function toCSV(patterns) {
  const esc = s => `"${String(s).replace(/"/g, '""')}"`;
  const lines = ['pattern,samples,avg_ms,p50_ms,p95_ms,p99_ms,slow_flag'];
  for (const p of patterns) {
    const avg = p.samples > 0 ? (p.p50 + p.p95 + p.p99) / 3 : 0;
    lines.push([
      esc(p.pattern),
      p.samples,
      avg.toFixed(2),
      p.p50.toFixed(2),
      p.p95.toFixed(2),
      p.p99.toFixed(2),
      p.slow ? 'true' : 'false'
    ].join(','));
  }
  return lines.join('\n') + '\n';
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

const OUT = `g/reports/query_perf_daily_${today}.json`;
fs.writeFileSync(OUT, JSON.stringify(report, null, 2));
console.log(`✅ Daily perf rollup → ${OUT}`);

if (CSV) {
  const OUTCSV = OUT.replace(/\.json$/, '.csv');
  fs.writeFileSync(OUTCSV, toCSV(patterns));
  console.log(`✅ CSV export → ${OUTCSV}`);
}
