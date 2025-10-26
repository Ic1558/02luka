#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const { ACTION_LOG } = require('./util/web_actions_log.cjs');
const { parseJsonl, aggregate } = require('./web_actions_rollup.cjs');

function ensureDir(filePath) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
}

function isoWeek(date) {
  const target = new Date(date.valueOf());
  const dayNr = (date.getUTCDay() + 6) % 7;
  target.setUTCDate(target.getUTCDate() - dayNr + 3);
  const firstThursday = new Date(Date.UTC(target.getUTCFullYear(), 0, 4));
  const diff = target - firstThursday;
  return 1 + Math.round(diff / (7 * 24 * 60 * 60 * 1000));
}

function isoYear(date) {
  const week = isoWeek(date);
  const month = date.getUTCMonth();
  const year = date.getUTCFullYear();
  if (week === 1 && month === 11) {
    return year + 1;
  }
  if (week >= 52 && month === 0) {
    return year - 1;
  }
  return year;
}

function filterByWeek(entries, targetYear, targetWeek) {
  return entries.filter((entry) => {
    if (!entry.ts) return false;
    const ts = new Date(entry.ts);
    const year = isoYear(ts);
    const week = isoWeek(ts);
    return year === targetYear && week === targetWeek;
  });
}

function aggregateByCaller(entries) {
  const map = new Map();
  for (const entry of entries) {
    const key = entry.caller || 'unknown';
    const bucket = map.get(key) || { caller: key, total: 0, success: 0, failure: 0, durations: [] };
    bucket.total += 1;
    if (entry.ok) {
      bucket.success += 1;
    } else {
      bucket.failure += 1;
    }
    bucket.durations.push(entry.ms || 0);
    map.set(key, bucket);
  }
  return Array.from(map.values()).map((item) => {
    const durations = item.durations.sort((a, b) => a - b);
    const avg = durations.length === 0 ? 0 : durations.reduce((sum, v) => sum + v, 0) / durations.length;
    const p95 = durations.length === 0 ? 0 : durations[Math.min(durations.length - 1, Math.floor(durations.length * 0.95))];
    return {
      caller: item.caller,
      total: item.total,
      success: item.success,
      failure: item.failure,
      errorRate: item.total === 0 ? 0 : item.failure / item.total,
      avgMs: avg,
      p95Ms: p95,
    };
  }).sort((a, b) => b.total - a.total);
}

function writeJson(filePath, data) {
  ensureDir(filePath);
  fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`);
}

function writeCsv(filePath, rows) {
  ensureDir(filePath);
  const headers = ['caller', 'total', 'success', 'failure', 'errorRate', 'avgMs', 'p95Ms'];
  const lines = [headers.join(',')];
  for (const row of rows) {
    lines.push(
      headers
        .map((key) => {
          const value = row[key];
          const str = value == null ? '' : String(value);
          if (str.includes(',') || str.includes('"') || str.includes('\n')) {
            return `"${str.replace(/"/g, '""')}"`;
          }
          return str;
        })
        .join(',')
    );
  }
  fs.writeFileSync(filePath, `${lines.join(os.EOL)}${os.EOL}`);
}

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--week') {
      args.week = argv[++i];
    } else if (token === '--input') {
      args.input = argv[++i];
    } else if (token === '--output') {
      args.output = argv[++i];
    }
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv);
  const baseDate = args.week ? new Date(`${args.week.slice(0, 4)}-01-01T00:00:00Z`) : new Date();
  const year = args.week ? Number(args.week.slice(0, 4)) : isoYear(baseDate);
  const week = args.week ? Number(args.week.slice(4)) : isoWeek(baseDate);
  const stamp = `${year}${String(week).padStart(2, '0')}`;

  const entries = parseJsonl(args.input || ACTION_LOG);
  const filtered = filterByWeek(entries, year, week);
  const summary = aggregate(filtered);
  const callers = aggregateByCaller(filtered);
  const reportDir = path.dirname(ACTION_LOG);
  const jsonPath = args.output || path.join(reportDir, `web_actions_weekly_${stamp}.json`);
  const csvPath = jsonPath.replace(/\.json$/, '.csv');

  writeJson(jsonPath, {
    generatedAt: new Date().toISOString(),
    week: stamp,
    summary,
    callers,
    totalActions: filtered.length,
  });
  writeCsv(csvPath, callers);
  console.log(`Weekly rollup ${stamp}: ${filtered.length} actions`);
}

if (require.main === module) {
  main().catch((err) => {
    console.error('Weekly rollup failed:', err);
    process.exitCode = 1;
  });
}

module.exports = {
  aggregateByCaller,
  filterByWeek,
};
