// hub/delegation_watchdog.mjs
import fs from 'fs';
import path from 'path';

const ROOT = process.env.LUKA_HOME || process.env.HOME + '/02luka';
const CFG  = process.env.WDG_CFG  || path.join(ROOT, 'config/delegation_watchdog.yaml');
const OUT  = process.env.WDG_OUT  || path.join(ROOT, 'hub/delegation_watchdog.json');

function readYamlSafe(p) {
  try {
    const s = fs.readFileSync(p, 'utf8');
    // very-light yaml: allow pure json or key: value pairs without nesting
    // prefer yaml parser if available
    try {
      const y = require('yaml');
      return y.parse(s);
    } catch {
      // fallback: tiny parser for simple forms
      const obj = {};
      s.split(/\r?\n/).forEach(line=>{
        const m = line.match(/^\s*([A-Za-z0-9_]+)\s*:\s*(.+?)\s*$/);
        if (m) obj[m[1]] = m[2];
      });
      return obj;
    }
  } catch { return {}; }
}

function safeJson(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); }
  catch { return fallback; }
}

const cfg = readYamlSafe(CFG);
const now = new Date().toISOString();

const health = safeJson(path.join(ROOT, 'hub/mcp_health.json'), {_meta:{},results:[]});
const index  = safeJson(path.join(ROOT, 'hub/index.json'), {_meta:{},items:[]});

const timeoutMs = Number(cfg.stuck_timeout_ms || 15*60*1000); // 15m
const maxQueue  = Number(cfg.max_pending || 20);

// toy logic: mark stuck when unhealthy MCP OR pending files pile up
const mcpUnhealthy = (health.results||[]).some(r => r.ok === false);
const pendingCount = (index.items||[]).filter(x=>String(x.status||'')==='pending').length;

const items = [];
if (mcpUnhealthy) {
  items.push({ id: 'MCP', stuck: true, reason: 'mcp_unhealthy', detail: (health._meta||{}) });
}
if (pendingCount > maxQueue) {
  items.push({ id: 'INDEX_QUEUE', stuck: true, reason: 'pending_overflow', pending: pendingCount });
}

const out = {
  _meta: {
    created_by: 'GG_Agent_02luka',
    created_at: now,
    source: 'delegation_watchdog.mjs',
    cfg_path: CFG
  },
  items
};

fs.mkdirSync(path.dirname(OUT), {recursive:true});
fs.writeFileSync(OUT, JSON.stringify(out, null, 2));
console.log(`✅ wrote ${OUT}`);
