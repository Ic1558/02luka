// Phase 8.7 – Predictive Maintenance (shadow)
// Reads ops_health.json + audit logs; produces 2–24h risk forecast.
// Modes: off|shadow|advice (we only act in advice, but bridge will gate to shadow).
const fs = require('fs');
const path = require('path');

const REPO = process.env.REPO_PATH || path.join(process.env.HOME || '', '02luka-repo');
const MET = p => path.join(REPO, 'g/metrics', p);
const LOG = p => path.join(REPO, 'g/logs', p);
const REP = p => path.join(REPO, 'g/reports', p);

function now(){ return new Date().toISOString(); }
function readJSON(p, fallback){ try{ return JSON.parse(fs.readFileSync(p,'utf8')); }catch{ return fallback; } }
function tailText(p, kb=256){ try{ const s = fs.statSync(p).size; const fd=fs.openSync(p,'r'); const len=Math.min(s,kb*1024); const buf=Buffer.alloc(len); fs.readSync(fd, buf, 0, len, s-len); fs.closeSync(fd); return buf.toString('utf8'); }catch{ return ''; } }
function ensureDir(p){ fs.mkdirSync(p, {recursive:true}); }

function pct(x){ return Math.round(x*1000)/10; }
function toMs(s){ return Number(s)||0; }

function summarizeHealth(h){
  // expects schema from ops_health_watcher: checks[], summary{}
  const checks = (h && h.checks) || [];
  const lastN = checks.slice(-36); // ~3h window at 5min interval
  const okCount = lastN.filter(c=> (c.success_rate ?? 0) >= 99.5).length;
  const avgLat = lastN.length ? Math.round(lastN.reduce((a,c)=>a+(c.avg_latency_ms||0),0)/lastN.length) : null;

  // recent trend: delta between last 3 and prior 3
  const recent = lastN.slice(-3);
  const prior  = lastN.slice(-6,-3);
  const rLat = recent.length ? recent.reduce((a,c)=>a+(c.avg_latency_ms||0),0)/recent.length : 0;
  const pLat = prior.length  ? prior.reduce((a,c)=>a+(c.avg_latency_ms||0),0)/prior.length  : rLat;
  const latTrend = rLat - pLat; // positive = getting slower

  // availability trend: success_rate median delta
  const m = arr => arr.length? arr.slice().sort((a,b)=>a-b)[Math.floor(arr.length/2)] : 0;
  const rSucc = m(recent.map(c=>c.success_rate||0));
  const pSucc = m(prior.map(c=>c.success_rate||0));
  const succTrend = rSucc - pSucc;

  return { window:lastN.length, okCount, avgLat, latTrend:Math.round(latTrend), succTrend:Math.round(succTrend*10)/10 };
}

function parseEvents(text, tag){
  // crude ISO extractor
  const items = [];
  (text||'').split('\n').forEach(line=>{
    const m = line.match(/\[(\d{4}-\d{2}-\d{2}T[^]+?)\]\s*(.*)$/) || line.match(/^(\d{4}-\d{2}-\d{2}T[^ ]+).*?-\s*(.*)$/);
    if (m) items.push({ ts:m[1], tag, msg:m[2].trim() });
  });
  return items.slice(-200);
}

function forecast(){
  const health = readJSON(MET('ops_health.json'), {checks:[], summary:{}});
  const sum = summarizeHealth(health);

  // lightweight signals
  const alerts = parseEvents(tailText(LOG('ops_alerts.log'), 256), 'alert');
  const heals  = parseEvents(tailText(LOG('ops_autoheal.log'), 256), 'autoheal');
  const maint  = parseEvents(tailText(LOG('maintenance_actions.log'), 64), 'maint');

  // rules → risk score 0..1
  let score = 0, notes = [];

  // R1: Latency trend up & avg > 1500ms → +0.3
  if ((sum.avgLat||0) > 1500 && sum.latTrend > 150) {
    score += 0.3; notes.push(`R1 latency rising: avg=${sum.avgLat}ms trend=+${sum.latTrend}ms`);
  }
  // R2: Availability drifting down (succTrend <-0.5) → +0.25
  if (sum.succTrend < -0.5) {
    score += 0.25; notes.push(`R2 availability drifting down: Δ${sum.succTrend}pp`);
  }
  // R3: Alerts > 2 in last ~hour → +0.25
  if (alerts.length >= 3) {
    score += 0.25; notes.push(`R3 frequent alerts: ${alerts.length} recent`);
  }
  // R4: Auto-heals >=2 recent → +0.2
  if (heals.length >= 2) {
    score += 0.2; notes.push(`R4 repeated auto-heal: ${heals.length} recent`);
  }
  // clamp
  score = Math.min(1, score);

  // map score → horizon + recommendation
  let horizonH = 24, level='low', suggest='observe'; // defaults
  if (score >= 0.75){ horizonH = 2; level='high'; suggest='prepare maintenance; inspect logs; consider pinning mode=local'; }
  else if (score >= 0.5){ horizonH = 6; level='medium'; suggest='increase sampling; pre-warm restarts; review recent diffs'; }
  else if (score >= 0.25){ horizonH = 12; level='watch'; suggest='tighten alert thresholds; schedule diagnostic pass'; }

  // build output
  const out = {
    generated_at: now(),
    mode: 'shadow',
    health: { window: sum.window, ok_windows: sum.okCount, avg_latency_ms: sum.avgLat, latency_trend_ms: sum.latTrend, success_trend_pp: sum.succTrend },
    events: { alerts: alerts.slice(-10), autoheal: heals.slice(-10), maintenance: maint.slice(-6) },
    score: Number(score.toFixed(2)),
    risk_level: level,
    horizon_hours: horizonH,
    suggest,
    notes
  };
  return out;
}

function writeReport(f){
  ensureDir(REP(''));
  const stamp = now().replace(/[-:]/g,'').replace(/\..+Z/,'Z');
  const p = REP(`ops_predict_${stamp}.md`);
  const body = [
    `# 02LUKA • Predictive Maintenance (${stamp})`,
    ``,
    `- Mode: ${f.mode}`,
    `- Risk: **${f.risk_level.toUpperCase()}** (score ${f.score})`,
    `- Horizon: **${f.horizon_hours}h**`,
    `- Suggest: ${f.suggest}`,
    ``,
    `## Health (recent)`,
    `- Checks: ${f.health.window}, OK windows: ${f.health.ok_windows}`,
    `- Avg Latency: ${f.health.avg_latency_ms ?? '-'} ms`,
    `- Latency Trend: ${f.health.latency_trend_ms} ms`,
    `- Success Trend: ${f.health.success_trend_pp} pp`,
    ``,
    `## Notes`,
    ...(f.notes.length? f.notes.map(n=>`- ${n}`): ['- (none)']),
    ``,
    `_shadow mode – no actions taken_`
  ].join('\n');
  fs.writeFileSync(p, body, 'utf8');
  return { path:p, body };
}

module.exports = { forecast, writeReport };
