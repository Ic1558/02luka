// Phase 8.5 — AI Ops Digest (rule-based NL summary; no external API)
// Reads health metrics + audit logs → writes a Markdown digest for the last 24h.
const fs = require('fs');
const path = require('path');

const REPO = process.env.REPO_PATH || path.join(process.env.HOME || '', '02luka-repo');
const METRICS = path.join(REPO, 'g/metrics/ops_health.json');
const LOGS = path.join(REPO, 'g/logs');
const REPORTS = path.join(REPO, 'g/reports');

const FILES = {
  maint:       path.join(LOGS, 'maintenance_actions.log'),
  autoheal:    path.join(LOGS, 'ops_autoheal.log'),
  alerts:      path.join(LOGS, 'ops_alerts.log'),
  verifierAny: (globDir => {
    try {
      const list = fs.readdirSync(path.join(REPO,'g/reports')).filter(x => x.startsWith('251021_verification_precise_'));
      list.sort().reverse();
      return list.length ? path.join(REPO,'g/reports', list[0]) : null;
    } catch { return null; }
  })()
};

function readJSON(p, d){ try { return JSON.parse(fs.readFileSync(p,'utf8')); } catch { return d; } }
function lines(p){ try { return fs.readFileSync(p,'utf8').split('\n').filter(Boolean); } catch { return []; } }
function isoNow(){ return new Date().toISOString(); }

function withinLastHours(ts, hours=24){
  try { return (Date.now() - Date.parse(ts)) <= hours*3600*1000; } catch { return false; }
}

// Parse "[ISO] message…" or "ISO message…"
function parseLogLine(line){
  const m = line.match(/^\[?(\d{4}-\d{2}-\d{2}T[^\] ]+Z)\]?\s+(.*)$/);
  return m ? { ts:m[1], msg:m[2] } : null;
}

function summarizeHealth(h){
  const s = h?.summary || {};
  return {
    checks: h?.checks?.length || 0,
    success: typeof s.recent_success_rate === 'number' ? s.recent_success_rate : null,
    latency: typeof s.recent_avg_latency_ms === 'number' ? s.recent_avg_latency_ms : null,
    uptime_h: typeof s.uptime_hours === 'number' ? s.uptime_hours : null
  };
}

function collectEvents(){
  const out = { maint:[], autoheal:[], alerts:[] };
  for (const [k,p] of Object.entries(FILES)){
    if (k === 'verifierAny') continue;
    if (!p) continue;
    for (const ln of lines(p)){
      const e = parseLogLine(ln);
      if (e && withinLastHours(e.ts,24)) out[k].push(e);
    }
    out[k].sort((a,b)=>a.ts<b.ts?1:-1);
  }
  return out;
}

function fmtNum(n){ return n==null ? '-' : (typeof n === 'number' ? n.toFixed(1) : String(n)); }

function buildMarkdown(){
  const now = isoNow();
  const health = readJSON(METRICS, null);
  const H = summarizeHealth(health);
  const E = collectEvents();

  const maintOn = E.maint.filter(e => /ENABLE/i.test(e.msg)).length;
  const maintOff= E.maint.filter(e => /DISABLE/i.test(e.msg)).length;

  const autoHeals = E.autoheal.length;
  const alerts = E.alerts.length;

  const sloAvail = H.success != null ? (H.success >= 99.5 ? '✅' : '⚠️') : '–';
  const sloLat   = H.latency != null ? (H.latency <= 2000 ? '✅' : '⚠️') : '–';

  let verifierNote = '';
  if (FILES.verifierAny) {
    try {
      const body = fs.readFileSync(FILES.verifierAny, 'utf8');
      verifierNote = body.includes('OVERALL: PASS') ? '✅ PASS' : (body.includes('FAIL') ? '❌ FAIL' : '–');
    } catch {}
  }

  const head = [
`# 02LUKA • AI Ops Digest (${now.slice(0,10)})`,
`Generated at ${now} (UTC)`,
``,
`## Summary`,
`- Availability (recent): **${fmtNum(H.success)}%** ${sloAvail}`,
`- Latency p(mean recent): **${fmtNum(H.latency)} ms** ${sloLat}`,
`- Health checks in window: **${H.checks}**`,
`- Uptime observed: **${fmtNum(H.uptime_h)} h**`,
`- Auto-heal actions: **${autoHeals}**`,
`- Alerts fired: **${alerts}**`,
`- Maintenance: **${maintOn}× ON**, **${maintOff}× OFF**`,
`- Nightly verifier: **${verifierNote}**`,
``].join('\n');

  const section = (title, arr) => {
    if (!arr.length) return `### ${title}\n- (none in last 24h)\n`;
    const lines = arr.slice(0,50).map(e => `- ${e.ts} — ${e.msg}`);
    return `### ${title}\n${lines.join('\n')}\n`;
  };

  const body = [
    section('Auto-Heal Actions', E.autoheal),
    section('Alerts', E.alerts),
    section('Maintenance Changes', E.maint),
  ].join('\n');

  const tail = [
`---`,
`_This digest summarizes last 24h from ops_health metrics + audit logs. Thresholds: availability ≥99.5%, latency ≤2000ms._`,
``].join('\n');

  return [head, body, tail].join('\n');
}

function ensureDir(p){ fs.mkdirSync(p, { recursive:true }); }

function writeDigest(){
  ensureDir(REPORTS);
  const stamp = new Date();
  const ymd = stamp.toISOString().slice(0,10).replace(/-/g,'');
  const out = path.join(REPORTS, `ops_digest_${ymd}.md`);
  const md = buildMarkdown();
  fs.writeFileSync(out, md, 'utf8');
  return out;
}

if (require.main === module) {
  const out = writeDigest();
  console.log(`Wrote digest: ${out}`);
}

module.exports = { writeDigest };
