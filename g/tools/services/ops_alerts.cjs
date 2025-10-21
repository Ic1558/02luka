// Phase 7.9 — Alerts on top of ops_health.json
import fs from 'fs';
import path from 'path';
const fetchFn = globalThis.fetch;

const REPO = process.env.REPO_PATH || path.join(process.env.HOME || '', '02luka-repo');
const HEALTH_FILE = path.join(REPO, 'g/metrics/ops_health.json');
const STATE_FILE  = path.join(REPO, 'g/state/ops_alert_state.json');
const LOG_FILE    = path.join(REPO, 'g/logs/ops_alerts.log');

const WEBHOOK = process.env.ALERT_WEBHOOK_URL || '';
const MIN_SUCCESS = Number(process.env.ALERT_MIN_SUCCESS || 95);
const MAX_LAT_MS  = Number(process.env.ALERT_MAX_AVG_LAT_MS || 2000);
const COOLDOWN_MIN = Number(process.env.ALERT_COOLDOWN_MIN || 15);

function readJSON(p, d) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return d; } }
function writeJSON(p, v) { fs.mkdirSync(path.dirname(p), {recursive:true}); fs.writeFileSync(p, JSON.stringify(v, null, 2)); }
function log(s){ fs.mkdirSync(path.dirname(LOG_FILE), {recursive:true}); fs.appendFileSync(LOG_FILE, `[${new Date().toISOString()}] ${s}\n`); }

function shouldAlert(sum, st){
  const now = Date.now();
  const last = st?.lastSentAt || 0;
  const inCooldown = (now - last) < COOLDOWN_MIN*60*1000;

  const reasons = [];
  if (typeof sum.recent_success_rate === 'number' && sum.recent_success_rate < MIN_SUCCESS) {
    reasons.push(`Success ${sum.recent_success_rate}% < ${MIN_SUCCESS}%`);
  }
  if (typeof sum.recent_avg_latency_ms === 'number' && sum.recent_avg_latency_ms > MAX_LAT_MS) {
    reasons.push(`Latency ${sum.recent_avg_latency_ms}ms > ${MAX_LAT_MS}ms`);
  }
  if (!reasons.length) return { fire:false, reasons:[] };
  if (inCooldown) return { fire:false, reasons, cooldown:true };
  return { fire:true, reasons };
}

async function sendWebhook(text, jsonExtra){
  if (!WEBHOOK) return;
  const body = { text, ...jsonExtra };
  await fetchFn(WEBHOOK, {
    method:'POST',
    headers:{'content-type':'application/json'},
    body: JSON.stringify(body)
  });
}

async function main(){
  const health = readJSON(HEALTH_FILE, null);
  if (!health?.summary) { log('skip: no health summary'); return; }
  const sum = health.summary;
  const st  = readJSON(STATE_FILE, { lastSentAt: 0 });

  const chk = shouldAlert(sum, st);
  if (!chk.reasons.length) { log('ok: within thresholds'); return; }
  if (!chk.fire) { log(`suppressed (cooldown): ${chk.reasons.join(' | ')}`); return; }

  const title = `⚠️ 02luka Ops Health Alert`;
  const lines = [
    `• Reasons: ${chk.reasons.join(' | ')}`,
    `• Last check: ${sum.last_check || 'n/a'}`,
    `• Success: ${sum.recent_success_rate ?? '-'}% (min ${MIN_SUCCESS}%)`,
    `• Avg latency: ${sum.recent_avg_latency_ms ?? '-'} ms (max ${MAX_LAT_MS} ms)`,
    `• Uptime(h): ${sum.uptime_hours ?? '-'}`,
  ];
  await sendWebhook(`${title}\n${lines.join('\n')}`, {});
  writeJSON(STATE_FILE, { lastSentAt: Date.now(), lastReasons: chk.reasons, lastSummary: sum });
  log(`ALERT sent: ${chk.reasons.join(' | ')}`);
}

main().catch(e=>{ log('error: '+e?.message); process.exit(1); });
