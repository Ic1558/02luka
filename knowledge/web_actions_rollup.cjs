#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const { ACTION_LOG } = require('./util/web_actions_log.cjs');

function ensureDir(filePath) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
}

function parseJsonl(filePath) {
  try {
    const data = fs.readFileSync(filePath, 'utf8');
    return data
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line) => {
        try {
          return JSON.parse(line);
        } catch (err) {
          return null;
        }
      })
      .filter(Boolean);
  } catch (err) {
    if (err.code === 'ENOENT') {
      return [];
    }
    throw err;
  }
}

function formatDate(date) {
  return `${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}${String(date.getDate()).padStart(2, '0')}`;
}

function quantile(arr, q) {
  if (arr.length === 0) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const pos = (sorted.length - 1) * q;
  const base = Math.floor(pos);
  const rest = pos - base;
  if (sorted[base + 1] !== undefined) {
    return sorted[base] + rest * (sorted[base + 1] - sorted[base]);
  }
  return sorted[base];
}

function aggregate(entries) {
  const durations = entries.map((entry) => entry.ms || 0);
  const success = entries.filter((entry) => entry.ok);
  const failure = entries.filter((entry) => !entry.ok);

  const byDomain = new Map();
  const byTool = new Map();
  const byCaller = new Map();

  for (const entry of entries) {
    if (entry.domain) {
      byDomain.set(entry.domain, (byDomain.get(entry.domain) || 0) + 1);
    }
    byTool.set(entry.tool, (byTool.get(entry.tool) || 0) + 1);
    byCaller.set(entry.caller, (byCaller.get(entry.caller) || 0) + 1);
  }

  const listFromMap = (map) =>
    Array.from(map.entries())
      .map(([key, count]) => ({ key, count }))
      .sort((a, b) => b.count - a.count);

  const slowActions = entries
    .filter((entry) => entry.ms >= 2000)
    .sort((a, b) => b.ms - a.ms)
    .slice(0, 20);

  return {
    total: entries.length,
    success: success.length,
    failure: failure.length,
    errorRate: entries.length === 0 ? 0 : failure.length / entries.length,
    duration: {
      p50: quantile(durations, 0.5),
      p95: quantile(durations, 0.95),
      p99: quantile(durations, 0.99),
      average: durations.length === 0 ? 0 : durations.reduce((sum, v) => sum + v, 0) / durations.length,
    },
    topDomains: listFromMap(byDomain),
    topTools: listFromMap(byTool),
    callers: listFromMap(byCaller),
    slowActions,
  };
}

function filterByDate(entries, date) {
  const prefix = date.toISOString().slice(0, 10);
  return entries.filter((entry) => typeof entry.ts === 'string' && entry.ts.startsWith(prefix));
}

function writeJson(filePath, data) {
  ensureDir(filePath);
  fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`);
}

function writeCsv(filePath, entries) {
  ensureDir(filePath);
  const headers = ['ts', 'id', 'caller', 'tool', 'status', 'ok', 'ms', 'domain', 'error'];
  const lines = [headers.join(',')];
  for (const entry of entries) {
    const row = [
      entry.ts,
      entry.id,
      entry.caller,
      entry.tool,
      entry.status,
      entry.ok,
      entry.ms,
      entry.domain || '',
      entry.error ? JSON.stringify(entry.error).slice(1, -1) : '',
    ];
    lines.push(row.map((value) => {
      const str = value == null ? '' : String(value);
      if (str.includes(',') || str.includes('"') || str.includes('\n')) {
        return `"${str.replace(/"/g, '""')}"`;
      }
      return str;
    }).join(','));
  }
  fs.writeFileSync(filePath, `${lines.join(os.EOL)}${os.EOL}`);
}

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--date') {
      args.date = argv[++i];
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
  const baseDate = args.date ? new Date(`${args.date}T00:00:00Z`) : new Date();
  const dayStamp = formatDate(baseDate);
  const entries = parseJsonl(args.input || ACTION_LOG);
  const filtered = filterByDate(entries, baseDate);
  const summary = aggregate(filtered);
  const reportDir = path.dirname(ACTION_LOG);
  const jsonPath = args.output || path.join(reportDir, `web_actions_daily_${dayStamp}.json`);
  const csvPath = jsonPath.replace(/\.json$/, '.csv');

  writeJson(jsonPath, {
    generatedAt: new Date().toISOString(),
    date: baseDate.toISOString().slice(0, 10),
    summary,
    totalActions: filtered.length,
  });
  writeCsv(csvPath, filtered);
  console.log(`Wrote ${filtered.length} entries to ${jsonPath} and ${csvPath}`);
}

if (require.main === module) {
  main().catch((err) => {
    console.error('Daily rollup failed:', err);
    process.exitCode = 1;
  });
}

module.exports = {
  aggregate,
  filterByDate,
  parseJsonl,
};
