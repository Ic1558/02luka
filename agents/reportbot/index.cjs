#!/usr/bin/env node
/**
 * Reportbot – daily ops summary aggregator
 *
 * Combines API (/api/reports/summary) data with local report files under g/reports
 * and emits a structured summary that downstream tooling (Discord notifier, schedulers)
 * can consume. Supports optional overrides for live runs via --counts/--status.
 */

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');
const { URL } = require('url');
const { writeArtifacts } = require('../../packages/io/atomicExport.cjs');

const repoRoot = path.resolve(__dirname, '..', '..');
const reportsDir = path.join(repoRoot, 'g', 'reports');
const latestMarkerPath = path.join(reportsDir, 'latest');
const summaryPath = path.join(reportsDir, 'OPS_SUMMARY.json');
const DEFAULT_API_URL = process.env.REPORTBOT_API_URL || 'http://127.0.0.1:4000/api/reports/summary';

const args = process.argv.slice(2);
const options = {
  write: false,
  text: false,
  noApi: false,
  counts: null,
  status: null,
  latest: null,
  channel: process.env.REPORT_CHANNEL || 'reports'
};

function printUsage() {
  console.log(`Usage: node agents/reportbot/index.cjs [options]\n\n` +
    `Options:\n` +
    `  --write             Persist summary to g/reports/OPS_SUMMARY.json\n` +
    `  --text              Output human readable text instead of JSON\n` +
    `  --no-api            Skip API fetch (filesystem only)\n` +
    `  --counts a,b,c      Override pass,warn,fail counts (e.g. 3,1,0 or pass=3,warn=1,fail=0)\n` +
    `  --status value      Override overall status (pass|warn|fail|unknown)\n` +
    `  --latest path       Provide path to latest report (absolute or relative)\n` +
    `  --channel name      Override target channel (default: ${options.channel})\n` +
    `  --help              Show this message`);
}

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--write') {
    options.write = true;
  } else if (arg === '--text') {
    options.text = true;
  } else if (arg === '--json') {
    options.text = false;
  } else if (arg === '--no-api') {
    options.noApi = true;
  } else if (arg === '--counts') {
    options.counts = args[i + 1];
    i += 1;
  } else if (arg.startsWith('--counts=')) {
    options.counts = arg.slice('--counts='.length);
  } else if (arg === '--status') {
    options.status = args[i + 1];
    i += 1;
  } else if (arg.startsWith('--status=')) {
    options.status = arg.slice('--status='.length);
  } else if (arg === '--latest') {
    options.latest = args[i + 1];
    i += 1;
  } else if (arg.startsWith('--latest=')) {
    options.latest = arg.slice('--latest='.length);
  } else if (arg === '--channel') {
    options.channel = args[i + 1];
    i += 1;
  } else if (arg.startsWith('--channel=')) {
    options.channel = arg.slice('--channel='.length);
  } else if (arg === '--help' || arg === '-h') {
    printUsage();
    process.exit(0);
  } else {
    console.error(`Unknown option: ${arg}`);
    printUsage();
    process.exit(1);
  }
}

function parseCounts(input) {
  if (!input) return null;
  const counts = { pass: 0, warn: 0, fail: 0 };
  const normalized = input.replace(/\s+/g, '');
  if (!normalized) return counts;
  if (/^[0-9]+,[0-9]+,[0-9]+$/.test(normalized)) {
    const [p, w, f] = normalized.split(',').map(v => Number.parseInt(v, 10) || 0);
    counts.pass = p;
    counts.warn = w;
    counts.fail = f;
    return counts;
  }
  normalized.split(',').forEach(part => {
    if (!part) return;
    const [key, value] = part.split('=');
    const lower = (key || '').toLowerCase();
    const num = Number.parseInt(value, 10) || 0;
    if (lower.startsWith('pass')) counts.pass = num;
    if (lower.startsWith('warn')) counts.warn = num;
    if (lower.startsWith('fail')) counts.fail = num;
  });
  return counts;
}

function normalizeStatus(value) {
  const lower = (value || '').toString().toLowerCase();
  if (['pass', 'ok', 'success'].includes(lower)) return 'pass';
  if (['warn', 'warning'].includes(lower)) return 'warn';
  if (['fail', 'failed', 'error'].includes(lower)) return 'fail';
  return 'unknown';
}

function fetchApiSummary(urlString) {
  return new Promise(resolve => {
    let parsed;
    try {
      parsed = new URL(urlString);
    } catch (error) {
      return resolve(null);
    }
    const requester = parsed.protocol === 'https:' ? https : http;
    const request = requester.request(
      parsed,
      {
        method: 'GET',
        timeout: 4500,
        headers: { Accept: 'application/json' }
      },
      res => {
        const chunks = [];
        res.on('data', chunk => chunks.push(chunk));
        res.on('end', () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            const body = Buffer.concat(chunks).toString('utf8');
            try {
              resolve(JSON.parse(body));
            } catch (error) {
              resolve(null);
            }
          } else {
            resolve(null);
          }
        });
      }
    );
    request.on('timeout', () => {
      request.destroy();
      resolve(null);
    });
    request.on('error', () => resolve(null));
    request.end();
  });
}

function readLatestMarker() {
  try {
    if (fs.existsSync(latestMarkerPath)) {
      const raw = fs.readFileSync(latestMarkerPath, 'utf8').trim();
      if (raw) {
        if (path.isAbsolute(raw)) {
          return raw;
        }
        return path.join(reportsDir, raw);
      }
    }
  } catch (error) {
    // ignore marker errors
  }
  return null;
}

function findLatestReport() {
  if (!fs.existsSync(reportsDir)) return null;
  const files = fs
    .readdirSync(reportsDir)
    .filter(f => /^OPS_ATOMIC_\d{6}_\d{6}\.md$/.test(f))
    .sort()
    .reverse();
  if (!files.length) return null;
  return path.join(reportsDir, files[0]);
}

function parseReportMarkdown(content) {
  if (!content) return null;
  const pass = (content.match(/\bPASS\b/g) || []).length;
  const warn = (content.match(/\bWARN\b/g) || []).length;
  const fail = (content.match(/\bFAIL\b/g) || []).length;
  let summary = '';
  const summaryMatch = content.match(/## Summary[\s\S]*?(?=\n## |$)/i);
  if (summaryMatch) {
    summary = summaryMatch[0].split('\n').slice(1).join('\n').trim();
  }
  if (!summary) {
    summary = `PASS=${pass} WARN=${warn} FAIL=${fail}`;
  }
  return { pass, warn, fail, summary };
}

function buildReportLink(fileName) {
  const base = process.env.REPORTBOT_REPORT_BASE_URL;
  if (!base || !fileName) return null;
  try {
    const normalizedBase = base.endsWith('/') ? base : `${base}/`;
    const url = new URL(fileName, normalizedBase);
    return url.toString();
  } catch (error) {
    return null;
  }
}

function determineStatus(counts) {
  if (counts.fail > 0) return 'fail';
  if (counts.warn > 0) return 'warn';
  if (counts.pass > 0) return 'pass';
  return 'unknown';
}

async function collectSummary() {
  const summary = {
    generatedAt: new Date().toISOString(),
    status: 'unknown',
    pass: 0,
    warn: 0,
    fail: 0,
    channel: options.channel,
    source: 'filesystem',
    summary: '',
    report: {
      file: null,
      path: null,
      link: null
    }
  };

  if (options.counts) {
    const overrides = parseCounts(options.counts);
    if (overrides) {
      summary.pass = overrides.pass;
      summary.warn = overrides.warn;
      summary.fail = overrides.fail;
    }
  }

  if (options.status) {
    summary.status = normalizeStatus(options.status);
  }

  let latestPath = null;
  if (options.latest) {
    latestPath = path.isAbsolute(options.latest)
      ? options.latest
      : path.join(repoRoot, options.latest);
  }
  if (!latestPath) {
    latestPath = readLatestMarker() || findLatestReport();
  }

  if (latestPath && fs.existsSync(latestPath)) {
    summary.report.path = latestPath;
    summary.report.file = path.basename(latestPath);
    summary.report.link = buildReportLink(summary.report.file);
    try {
      const content = fs.readFileSync(latestPath, 'utf8');
      const parsed = parseReportMarkdown(content);
      if (parsed) {
        if (!options.counts) {
          summary.pass = parsed.pass;
          summary.warn = parsed.warn;
          summary.fail = parsed.fail;
        }
        if (!summary.summary) {
          summary.summary = parsed.summary;
        }
      }
    } catch (error) {
      // ignore parse errors
    }
  }

  if (!options.noApi) {
    const apiData = await fetchApiSummary(DEFAULT_API_URL);
    if (apiData && typeof apiData === 'object') {
      summary.source = 'api';
      if (!options.counts) {
        if (typeof apiData.pass === 'number') summary.pass = apiData.pass;
        if (typeof apiData.warn === 'number') summary.warn = apiData.warn;
        if (typeof apiData.fail === 'number') summary.fail = apiData.fail;
      }
      if (!options.status && apiData.status) {
        summary.status = normalizeStatus(apiData.status);
      }
      if (!summary.summary && apiData.summary) {
        summary.summary = String(apiData.summary).trim();
      }
      if (apiData.latestReport) {
        if (apiData.latestReport.file) {
          summary.report.file = apiData.latestReport.file;
        }
        if (apiData.latestReport.path) {
          summary.report.path = path.isAbsolute(apiData.latestReport.path)
            ? apiData.latestReport.path
            : path.join(repoRoot, apiData.latestReport.path);
        }
        if (apiData.latestReport.link) {
          summary.report.link = apiData.latestReport.link;
        }
      }
    }
  }

  if (!summary.summary || Boolean(options.counts)) {
    summary.summary = `PASS=${summary.pass} WARN=${summary.warn} FAIL=${summary.fail}`;
  }

  if (summary.status === 'unknown') {
    summary.status = determineStatus(summary);
  }

  return summary;
}

function formatSummaryText(summary) {
  const overall = summary.status.toUpperCase();
  const countsText = `PASS=${summary.pass} WARN=${summary.warn} FAIL=${summary.fail}`;
  const latest = summary.report.file ? summary.report.file : 'none';
  return `${overall} — ${countsText} | Latest: ${latest}`;
}

(async () => {
  const summary = await collectSummary();
  if (options.write) {
    try {
      await writeArtifacts({
        targetDir: path.dirname(summaryPath),
        artifacts: [{ name: path.basename(summaryPath), data: `${JSON.stringify(summary, null, 2)}\n` }],
        log: { log: () => {} } // Silent mode
      });
    } catch (error) {
      console.error(`Failed to write ${summaryPath}:`, error.message);
      process.exit(1);
    }
  }

  if (options.text) {
    console.log(formatSummaryText(summary));
  } else {
    console.log(JSON.stringify(summary, null, 2));
  }
})();
