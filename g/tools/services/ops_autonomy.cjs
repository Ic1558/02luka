#!/usr/bin/env node
/**
 * Phase 9.0 — Autonomy (advice → auto)
 * - Reads predictive + correlation reports
 * - Decides actions with thresholds & cooldowns
 * - Publishes either advice (Kim) or intents (Redis) depending on AUTO_MODE
 */
const fs = require('fs'), path = require('path'), cp = require('child_process');

const ROOT = path.resolve(__dirname, '../../..');
const REP = p=>path.join(ROOT, 'g', 'reports', p);
const STATE = p=>path.join(ROOT, 'g', 'state', p);
const LOGS = p=>path.join(ROOT, 'g', 'logs', p);

const AUTO_MODE = (process.env.AUTO_MODE || 'off').toLowerCase(); // off|advice|auto
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const KIM_OUT = process.env.KIM_OUT_CH || 'kim:out';
const CHAT_ID = process.env.KIM_CHAT_ID || 'IC';

// thresholds & safety
const THRESH = {
  risk: Number(process.env.AUTO_RISK_MIN || 0.75),
  conf: Number(process.env.AUTO_CONF_MIN || 0.80),
  perSvcCooldownMin: Number(process.env.AUTO_SVC_COOLDOWN_MIN || 15),
  globalMaxPerHour: Number(process.env.AUTO_MAX_PER_HOUR || 3),
};

const SVC_ALLOW = (process.env.AUTO_SERVICES_ALLOW || 'bridge,clc_listener')
  .split(',').map(s=>s.trim()).filter(Boolean);

function tailNewest(prefix) {
  try {
    const dir = path.join(ROOT,'g','reports');
    const files = fs.readdirSync(dir).filter(f=>f.startsWith(prefix)).sort().reverse();
    if (!files.length) return null;
    const body = fs.readFileSync(path.join(dir, files[0]), 'utf8');
    return { file: files[0], body };
  } catch { return null; }
}

function parsePredict() {
  const hit = tailNewest('ops_predict_');
  if (!hit) return null;
  // try JSON block in file or fallback to heuristics
  const m = hit.body.match(/\{[\s\S]*"risk_level"[\s\S]*\}/);
  if (m) {
    try { return { src: hit.file, json: JSON.parse(m[0]) }; } catch {}
  }
  // crude scrape of sample MD
  const riskM = hit.body.match(/risk:\s*(high|medium|watch|low)/i);
  const scoreM = hit.body.match(/score\s*[:=]\s*([0-9.]+)/i);
  return { src: hit.file, json: { risk_level: riskM?.[1]?.toLowerCase() || 'low', score: Number(scoreM?.[1]||0) }};
}

function parseCorrelation() {
  const hit = tailNewest('ops_correlation_');
  if (!hit) return null;
  // find any confidence numbers in a JSON block first
  const jsonBlock = hit.body.match(/\{[\s\S]*"findings"[\s\S]*\}/);
  if (jsonBlock) {
    try { return { src: hit.file, json: JSON.parse(jsonBlock[0]) }; } catch {}
  }
  // fallback: scan confidences in MD
  const confs = [...hit.body.matchAll(/Confidence:\s*([0-9.]+)/gi)].map(x=>Number(x[1])).filter(x=>!isNaN(x));
  const max = confs.length ? Math.max(...confs) : 0;
  // crude extract a service name if present
  const svcM = hit.body.match(/###\s+F\d+\s+—\s+([a-z_]+)\s+—/i);
  return { src: hit.file, json: { findings: [{ service: svcM?.[1]||'bridge', confidence: max }] } };
}

// state helpers
function readJSON(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p,'utf8')); } catch { return fallback; }
}
function writeJSON(p, obj) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p + '.tmp', JSON.stringify(obj,null,2));
  fs.renameSync(p + '.tmp', p);
}

function minutesSince(ts) { return (Date.now() - ts) / 60000; }

function publishKim(text) {
  const payload = JSON.stringify({ chat_id: CHAT_ID, text });
  try {
    cp.execSync(`redis-cli -u "${REDIS_URL}" PUBLISH "${KIM_OUT}" '${payload.replace(/'/g,"'\\''")}'`, { stdio:'ignore' });
  } catch {}
}
function publishIntent(intent) {
  // intent: {kind:'restart'|'maintenance', target?, reason, src:{predict,correl}}
  const payload = JSON.stringify(intent);
  try {
    cp.execSync(`redis-cli -u "${REDIS_URL}" PUBLISH "ops:action" '${payload.replace(/'/g,"'\\''")}'`, { stdio:'ignore' });
  } catch (e) {
    log(`INTENT PUBLISH ERROR: ${e.message}`);
  }
}

function log(line) {
  const msg = `[${new Date().toISOString()}] ${line}\n`;
  fs.appendFileSync(LOGS('ops_autonomy.log'), msg);
}

// decision
function decide() {
  const pred = parsePredict();
  const corr = parseCorrelation();

  const score = Number(pred?.json?.score ?? (
    { high:0.85, medium:0.6, watch:0.35, low:0.1 }[(pred?.json?.risk_level||'low')] || 0.1
  ));
  const maxConf = Math.max(...(corr?.json?.findings||[]).map(f=>Number(f.confidence||0)), 0);
  const topSvc = (corr?.json?.findings||[]).sort((a,b)=>Number(b.confidence||0)-Number(a.confidence||0))[0]?.service || 'bridge';

  const eligibleSvc = SVC_ALLOW.includes(topSvc) ? topSvc : 'bridge';
  const wantAction = (score >= THRESH.risk) || (maxConf >= THRESH.conf);

  return {
    ts: new Date().toISOString(),
    mode: AUTO_MODE,
    score, maxConf,
    predSrc: pred?.src || null,
    corrSrc: corr?.src || null,
    suggested: wantAction ? { kind: 'restart', target: eligibleSvc, reason: `score=${score.toFixed(2)} conf=${maxConf.toFixed(2)}` } : { kind:'none' }
  };
}

function allowedByCooldown(state, intent) {
  if (intent.kind !== 'restart') return true;
  const now = Date.now();
  state.cooldown = state.cooldown || {};
  const svc = intent.target;
  const lastTs = state.cooldown[svc] || 0;
  const since = (now - lastTs)/60000;
  return since >= THRESH.perSvcCooldownMin;
}

function allowedByRate(state) {
  const now = Date.now();
  state.history = (state.history||[]).filter(t => (now - t) < 3600_000);
  return state.history.length < THRESH.globalMaxPerHour;
}

function recordAction(state, intent) {
  const now = Date.now();
  state.history = (state.history||[]);
  state.history.push(now);
  if (intent.kind === 'restart') {
    state.cooldown = state.cooldown || {};
    state.cooldown[intent.target] = now;
  }
}

// main
(function main(){
  const statusPath = STATE('ops_autonomy_status.json');
  const statePath = STATE('ops_autonomy_state.json');

  const evalRes = decide();
  let state = readJSON(statePath, { history:[], cooldown:{} });

  const summary = `AUTO:${evalRes.mode} score=${evalRes.score.toFixed(2)} conf=${evalRes.maxConf.toFixed(2)} → ${evalRes.suggested.kind}${evalRes.suggested.target?':'+evalRes.suggested.target:''}`;

  if (evalRes.suggested.kind === 'none') {
    writeJSON(statusPath, { ok:true, ...evalRes, summary });
    log(`NOOP ${summary}`);
    if (AUTO_MODE === 'advice') publishKim(`ℹ️ AUTO-ADVICE: no action ( ${summary} )`);
    return;
  }

  // enforcement gates
  const coolOK = allowedByCooldown(state, evalRes.suggested);
  const rateOK = allowedByRate(state);

  const gates = { coolOK, rateOK };
  const out = { ok:true, ...evalRes, gates, summary };

  if (AUTO_MODE === 'off') {
    writeJSON(statusPath, out);
    log(`OFF ${summary}`);
    return;
  }

  if (AUTO_MODE === 'advice') {
    writeJSON(statusPath, out);
    publishKim(`⚠️ AUTO-ADVICE: suggest ${evalRes.suggested.kind}${evalRes.suggested.target?(':'+evalRes.suggested.target):''} (${evalRes.suggested.reason})`);
    log(`ADVICE ${summary}`);
    return;
  }

  // AUTO mode
  if (!coolOK || !rateOK) {
    writeJSON(statusPath, { ok:true, ...evalRes, gates, summary, skipped:true });
    const reason = !coolOK ? `cooldown(${THRESH.perSvcCooldownMin}m)` : `rate-limit(${THRESH.globalMaxPerHour}/h)`;
    publishKim(`⏸️ AUTO-SKIP: ${evalRes.suggested.kind}:${evalRes.suggested.target} due to ${reason}`);
    log(`SKIP ${summary} :: ${reason}`);
    return;
  }

  // publish executable intent to ops_autoheal
  const intent = { ...evalRes.suggested, source:'autonomy', ts:evalRes.ts };
  publishIntent(intent);
  recordAction(state, intent);
  writeJSON(statePath, state);
  writeJSON(statusPath, { ok:true, ...evalRes, gates, summary, dispatched:true });
  publishKim(`✅ AUTO-EXEC (intent): ${intent.kind}${intent.target?':'+intent.target:''} — ${evalRes.suggested.reason}`);
  log(`EXEC ${summary}`);
})();
