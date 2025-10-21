// Phase 7.9 — Daily markdown report from ops_health.json
import fs from 'fs';
import path from 'path';
const fetchFn = globalThis.fetch;

const REPO = process.env.REPO_PATH || path.join(process.env.HOME || '', '02luka-repo');
const HEALTH_FILE = path.join(REPO, 'g/metrics/ops_health.json');
const REPORT_DIR  = path.join(REPO, 'g/reports');
const WEBHOOK = process.env.ALERT_WEBHOOK_URL || '';

function readJSON(p, d){ try { return JSON.parse(fs.readFileSync(p,'utf8')); } catch { return d; } }
function pad2(n){ return String(n).padStart(2,'0'); }
function todayYMD(){
  const d = new Date();
  return d.getFullYear()+pad2(d.getMonth()+1)+pad2(d.getDate());
}
function mdHeading(t){ return `## ${t}\n\n`; }

function makeReport(h){
  const checks = h?.checks || [];
  const sum = h?.summary || {};
  const fromTs = Date.now() - 24*3600*1000;
  const last24 = checks.filter(c => new Date(c.timestamp).getTime() >= fromTs);

  const succ = last24.map(c=>c.success_rate).filter(v=>Number.isFinite(v));
  const lat  = last24.map(c=>c.avg_latency_ms).filter(v=>Number.isFinite(v));
  const avg = arr => arr.length? Math.round(arr.reduce((a,b)=>a+b,0)/arr.length) : 0;
  const min = arr => arr.length? Math.min(...arr) : 0;
  const max = arr => arr.length? Math.max(...arr) : 0;

  const lines = [];
  lines.push(`# 02luka Ops Health — Daily Report (${new Date().toISOString()})\n`);
  lines.push(mdHeading('Summary'));
  lines.push(`- Checks (24h): **${last24.length}**`);
  lines.push(`- Success (avg/min): **${avg(succ)}%** / **${min(succ)}%**`);
  lines.push(`- Avg latency (avg/max): **${avg(lat)} ms** / **${max(lat)} ms**`);
  lines.push(`- Recent (watcher): success **${sum.recent_success_rate ?? '-'}%**, avg lat **${sum.recent_avg_latency_ms ?? '-'} ms**`);
  lines.push('\n');

  lines.push(mdHeading('Last 10 Checks'));
  last24.slice(-10).forEach(c=>{
    lines.push(`- ${c.timestamp} — success ${c.success_rate ?? '-'}% · avg ${c.avg_latency_ms ?? '-'} ms`);
  });
  lines.push('\n');

  return lines.join('\n');
}

async function sendWebhook(text){ if (!WEBHOOK) return;
  await fetchFn(WEBHOOK, { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({ text })});
}

(function main(){
  const h = readJSON(HEALTH_FILE, null);
  if (!h) { console.error('no ops_health.json'); process.exit(0); }
  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const file = path.join(REPO, 'g/reports', `ops_health_daily_${todayYMD()}.md`);
  const md = makeReport(h);
  fs.writeFileSync(file, md, 'utf8');
  if (WEBHOOK) sendWebhook(`🗞️ 02luka Daily Health: ${file.split('/').slice(-1)[0]}`).catch(()=>{});
  console.log('wrote', file);
})();
