// Phase 8.6 — Incident Correlation (shadow/advice)
// Inputs: g/metrics/ops_health.json + g/logs/{ops_alerts,ops_autoheal,maintenance_actions}.log
// Output: g/metrics/ops_correlation.json + g/reports/ops_correlation_YYYYMMDDTHHMM.md
// Mode: OPS_CORRELATE_MODE = off | shadow | advice  (default shadow; no actions)

const fs = require('fs');
const path = require('path');

const REPO = process.env.REPO_PATH || path.join(process.env.HOME || '', '02luka-repo');
const METR = path.join(REPO, 'g/metrics');
const LOGS = path.join(REPO, 'g/logs');
const REPS = path.join(REPO, 'g/reports');

const MODE = String(process.env.OPS_CORRELATE_MODE || 'shadow').toLowerCase(); // off|shadow|advice

const FILES = {
  health: path.join(METR, 'ops_health.json'),
  alerts: path.join(LOGS, 'ops_alerts.log'),
  autoheal: path.join(LOGS, 'ops_autoheal.log'),
  maintenance: path.join(LOGS, 'maintenance_actions.log'),
  verifierLatest: (() => {
    try {
      const list = fs.readdirSync(REPS).filter(x => x.startsWith('251021_verification_precise_'));
      list.sort().reverse();
      return list[0] ? path.join(REPS, list[0]) : null;
    } catch { return null; }
  })()
};

function loadJSON(p, d=null){ try { return JSON.parse(fs.readFileSync(p,'utf8')); } catch { return d; } }
function readLines(p){ try { return fs.readFileSync(p,'utf8').split('\n').filter(Boolean); } catch { return []; } }
function isoNow(){ return new Date().toISOString(); }
function ensureDir(d){ fs.mkdirSync(d, { recursive:true }); }

function parseLine(line){
  // [ISO] message OR ISO message
  const m = line.match(/^\[?(\d{4}-\d{2}-\d{2}T[^\] ]+Z)\]?\s+(.*)$/);
  return m ? { ts:m[1], msg:m[2] } : null;
}
function within(ts, ms){ try { return (Date.now() - Date.parse(ts)) <= ms; } catch { return false; } }
function windowItems(lines, mins=60){
  const ms = mins*60*1000;
  return lines.map(parseLine).filter(Boolean).filter(e => within(e.ts, ms));
}

function summarizeHealth(h){
  const checks = h?.checks || [];
  const s = h?.summary || {};
  return {
    recentSuccess: typeof s.recent_success_rate === 'number' ? s.recent_success_rate : null,
    recentLatency: typeof s.recent_avg_latency_ms === 'number' ? s.recent_avg_latency_ms : null,
    totalChecks: checks.length || 0
  };
}

function verdict(health, winAlerts, winHeals, maintOn, verifierFail){
  // Simple heuristics → findings
  const f = [];

  // R1: Latency spike + 2+ alerts in 10m + no maintenance → bridge congestion
  if ((health.recentLatency!=null && health.recentLatency > 2000) && winAlerts.length >= 2 && !maintOn) {
    f.push({
      service: 'bridge',
      cause: 'latency_spike',
      suggest: 'restart bridge; check request volume and tunnel status',
      confidence: 0.7,
      evidence: [
        `recentLatency=${health.recentLatency}ms > 2000`,
        `alerts_10m=${winAlerts.length}`,
        `maintenance=${maintOn}`
      ]
    });
  }

  // R2: Success dip + auto-heal restarted same service ≥2 in 30m → instability
  const restarts = winHeals
    .map(e => (e.msg.match(/restart:\s*([a-zA-Z0-9_\-]+)/) || [,'?'])[1])
    .filter(Boolean);
  const restartCounts = restarts.reduce((m,k)=> (m[k]=(m[k]||0)+1, m), {});
  const unstable = Object.entries(restartCounts).filter(([,n]) => n >= 2);

  if ((health.recentSuccess!=null && health.recentSuccess < 98.0) && unstable.length) {
    f.push({
      service: unstable[0][0] || 'unknown',
      cause: 'service_instability',
      suggest: `lock maintenance; inspect ${unstable[0][0]} logs; consider rollback`,
      confidence: 0.75,
      evidence: [
        `recentSuccess=${health.recentSuccess}% < 98`,
        `autoheal_restarts_30m=${JSON.stringify(restartCounts)}`
      ]
    });
  }

  // R3: Verifier FAIL in last run → regression
  if (verifierFail) {
    f.push({
      service: 'system',
      cause: 'nightly_verifier_fail',
      suggest: 'rollback last change; re-run precise verifier',
      confidence: 0.8,
      evidence: ['latest verifier report indicates FAIL']
    });
  }

  // R4: Maintenance ON >30m + health still red → stuck maintenance
  if (maintOn && (health.recentSuccess!=null && health.recentSuccess < 95.0)) {
    f.push({
      service: 'system',
      cause: 'maintenance_stuck',
      suggest: 'escalate; disable auto-heal; manual triage',
      confidence: 0.6,
      evidence: [
        `maintenance=ON`,
        `recentSuccess=${health.recentSuccess}% < 95`
      ]
    });
  }

  return f;
}

function maintenanceONLast30m() {
  // Look for ENABLE without matching DISABLE in last 30m → assume ON
  const L = windowItems(readLines(FILES.maintenance), 30);
  const on = L.filter(e => /ENABLE/i.test(e.msg)).length;
  const off = L.filter(e => /DISABLE/i.test(e.msg)).length;
  return on > off;
}

function verifierFAIL() {
  if (!FILES.verifierLatest) return false;
  try {
    const body = fs.readFileSync(FILES.verifierLatest, 'utf8');
    return body.includes('FAIL') && !body.includes('✅ OVERALL: PASS');
  } catch { return false; }
}

function buildFindings(){
  const now = isoNow();
  const health = loadJSON(FILES.health, null);
  const H = summarizeHealth(health);

  const alerts10 = windowItems(readLines(FILES.alerts), 10);
  const heals30 = windowItems(readLines(FILES.autoheal), 30);
  const maintOn = maintenanceONLast30m();
  const vFail = verifierFAIL();

  const findings = verdict(H, alerts10, heals30, maintOn, vFail).map(x => ({
    ...x, generated_at: now
  }));

  return { generated_at: now, window: { alerts_min:10, autoheal_min:30 }, health: H, findings };
}

function writeOutputs(){
  const data = buildFindings();
  ensureDir(METR); ensureDir(REPS);

  const jsonPath = path.join(METR, 'ops_correlation.json');
  fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2), 'utf8');

  const stamp = data.generated_at.replace(/[-:]/g,'').replace(/\..+Z/,'Z');
  const repPath = path.join(REPS, `ops_correlation_${stamp}.md`);
  const md = [
    `# 02LUKA • Incident Correlation (${data.generated_at})`,
    ``,
    `## Health (recent)`,
    `- Success: ${data.health.recentSuccess ?? '-'}%`,
    `- Latency: ${data.health.recentLatency ?? '-'} ms`,
    `- Checks: ${data.health.totalChecks}`,
    ``,
    `## Findings`,
    data.findings.length ? data.findings.map((f,i)=>(
      `### F${i+1} — ${f.service} — ${f.cause}\n`+
      `- Suggest: ${f.suggest}\n`+
      `- Confidence: ${f.confidence}\n`+
      `- Evidence:\n`+
      f.evidence.map(e=>`  - ${e}`).join('\n')
    )).join('\n\n') : '- (none)',
    ``,
    `---`,
    `_Window: alerts=10m, auto-heal=30m; Mode=${MODE}_`
  ].join('\n');
  fs.writeFileSync(repPath, md, 'utf8');

  return { jsonPath, repPath, data };
}

if (require.main === module) {
  if (MODE === 'off') { console.log('Correlation disabled (MODE=off)'); process.exit(0); }
  const out = writeOutputs();
  console.log(`Correlation written: ${out.jsonPath} & ${out.repPath}`);
}

module.exports = { writeOutputs, MODE };
