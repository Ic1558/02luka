// Phase 8.0 — Self-Healing based on ops_health.json
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
const fetchFn = globalThis.fetch;

const REPO = process.env.REPO_PATH || path.join(process.env.HOME || '', '02luka-repo');
const HEALTH_FILE = path.join(REPO, 'g/metrics/ops_health.json');
const STATE_FILE  = path.join(REPO, 'g/state/ops_autoheal_state.json');
const MAINT_FLAG  = path.join(REPO, 'g/state/maintenance.flag');
const LOG_FILE    = path.join(REPO, 'g/logs/ops_autoheal.log');

const TARGETS = (process.env.AUTOHEAL_TARGETS || 'bridge,clc_listener').split(',').map(s=>s.trim()).filter(Boolean);
const FAIL_CONSEC = Number(process.env.AUTOHEAL_FAIL_CONSEC || 3);
const COOLDOWN_MS = Number(process.env.AUTOHEAL_COOLDOWN_SEC || 600)*1000;
const MAX_ATTEMPTS_30M = Number(process.env.AUTOHEAL_MAX_ATTEMPTS_30M || 3);

const WEBHOOK = process.env.ALERT_WEBHOOK_URL || '';
const DOCKER_BIN = process.env.DOCKER_BIN || 'docker';

function nowISO(){ return new Date().toISOString(); }
function readJSON(p, d){ try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return d; } }
function writeJSON(p, v){ fs.mkdirSync(path.dirname(p), {recursive:true}); fs.writeFileSync(p, JSON.stringify(v, null, 2)); }
function log(s){ fs.mkdirSync(path.dirname(LOG_FILE), {recursive:true}); fs.appendFileSync(LOG_FILE, `[${nowISO()}] ${s}\n`); }

function healthBad(h){
  const sum = h?.summary || {};
  if (typeof sum.recent_success_rate !== 'number') return true;
  if (sum.recent_success_rate < 95) return true;
  if (typeof sum.recent_avg_latency_ms === 'number' && sum.recent_avg_latency_ms > 2000) return true;
  return false;
}

async function sendWebhook(text){
  if (!WEBHOOK) return;
  try {
    await fetchFn(WEBHOOK, { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({ text }) });
  } catch {}
}

function restartServices(names){
  names.forEach(n=>{
    try {
      execSync(`${DOCKER_BIN} restart ${n}`, { stdio:'ignore' });
      log(`restart: ${n}`);
    } catch (e) {
      log(`restart failed: ${n} (${e?.message||e})`);
    }
  });
}

(function main(){
  const h = readJSON(HEALTH_FILE, null);
  if (!h || !h.summary) { log('skip: no health summary'); return; }

  const st = readJSON(STATE_FILE, { badStreak: 0, lastActionAt: 0, actions: [] });

  const isBad = healthBad(h);
  const now = Date.now();

  if (!isBad) {
    // clear streak and maintenance if currently OK
    if (fs.existsSync(MAINT_FLAG)) {
      log('health OK → clearing maintenance flag');
      try { fs.unlinkSync(MAINT_FLAG); } catch {}
    }
    if (st.badStreak !== 0) {
      st.badStreak = 0;
      writeJSON(STATE_FILE, st);
      log('health OK → reset badStreak');
    }
    return;
  }

  // bad health
  st.badStreak = (st.badStreak || 0) + 1;

  const inCooldown = (now - (st.lastActionAt || 0)) < COOLDOWN_MS;
  if (st.badStreak < FAIL_CONSEC) {
    writeJSON(STATE_FILE, st);
    log(`bad health streak ${st.badStreak}/${FAIL_CONSEC}, waiting`);
    return;
  }
  if (inCooldown) {
    writeJSON(STATE_FILE, st);
    log(`cooldown active, skipping heal`);
    return;
  }

  // take healing action
  restartServices(TARGETS);
  st.lastActionAt = now;
  st.actions = (st.actions||[]).filter(t => (now - t) <= 30*60*1000); // keep last 30m
  st.actions.push(now);
  writeJSON(STATE_FILE, st);

  const msg = `🛠 Auto-heal: restarted [${TARGETS.join(', ')}] (badStreak=${st.badStreak}, actions30m=${st.actions.length})`;
  log(msg); sendWebhook(msg);

  // too many actions in 30 mins → set maintenance
  if (st.actions.length >= MAX_ATTEMPTS_30M && !fs.existsSync(MAINT_FLAG)) {
    fs.mkdirSync(path.dirname(MAINT_FLAG), { recursive:true });
    fs.writeFileSync(MAINT_FLAG, nowISO() + ' autohealed-too-often\n');
    const m2 = `🚧 Entering maintenance mode (too many heal attempts in 30m)`;
    log(m2); sendWebhook(m2);
  }
})();
