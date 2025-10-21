// Read-only audit collector for Ops UI
// Combines: maintenance_actions.log, ops_autoheal.log, ops_alerts.log
const fs = require('fs');
const path = require('path');

const REPO = process.env.REPO_PATH || path.join(process.env.HOME || '', '02luka-repo');
const LOGS = path.join(REPO, 'g/logs');

const FILES = [
  { file: 'maintenance_actions.log', type: 'maint'    },
  { file: 'ops_autoheal.log',        type: 'autoheal' },
  { file: 'ops_alerts.log',          type: 'alerts'   },
];

function tailRead(filePath, maxBytes = 512 * 1024) {
  try {
    const stat = fs.statSync(filePath);
    const size = stat.size;
    const start = Math.max(0, size - maxBytes);
    const fd = fs.openSync(filePath, 'r');
    const buf = Buffer.alloc(size - start);
    fs.readSync(fd, buf, 0, buf.length, start);
    fs.closeSync(fd);
    return buf.toString('utf8');
  } catch { return ''; }
}

function parseLine(line, fallbackType) {
  // Formats we expect:
  // [2025-10-22T02:31:00.000Z] message ...
  // or "2025-10-22T02:31:00.000Z autohealed-too-often" (maintenance.flag content)
  const m = line.match(/^\[?(\d{4}-\d{2}-\d{2}T[^ \]]+Z)\]?\s+(.*)$/);
  if (!m) return null;
  return { ts: m[1], type: fallbackType, msg: m[2], raw: line };
}

function loadOne(fp, type, limit) {
  const body = tailRead(fp);
  if (!body) return [];
  const lines = body.split('\n').filter(Boolean);
  const out = [];
  for (const ln of lines) {
    const e = parseLine(ln, type);
    if (e) out.push(e);
  }
  // newest first by timestamp
  out.sort((a, b) => (a.ts < b.ts ? 1 : -1));
  return limit ? out.slice(0, limit) : out;
}

function readAudit({ type = 'all', limit = 200 } = {}) {
  const lim = Math.max(1, Math.min(Number(limit) || 200, 1000));
  const types = new Set(['maint','autoheal','alerts']);
  const wantAll = type === 'all' || !types.has(type);

  let items = [];
  for (const f of FILES) {
    if (!wantAll && f.type !== type) continue;
    const fp = path.join(LOGS, f.file);
    items = items.concat(loadOne(fp, f.type, lim));
  }
  // merge all + re-sort + global limit
  items.sort((a, b) => (a.ts < b.ts ? 1 : -1));
  return items.slice(0, lim);
}

module.exports = { readAudit };
