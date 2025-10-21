const { execSync } = require('child_process');
const { readFileSync } = require('fs');
const path = require('path');

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const KIM_OUT = process.env.KIM_OUT_CH || 'kim:out';
const CHAT_ID = process.env.KIM_CHAT_ID || 'IC'; // set your chat id if needed

const ROOT = (()=>{
  const cands = [
    process.env.HOME + '/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo',
    '/workspaces/02luka-repo'
  ];
  for (const d of cands) { try { execSync(`test -d "${d}"`); return d; } catch {} }
  throw new Error('Repo root not found');
})();

function publish(text){
  const payload = JSON.stringify({ chat_id: CHAT_ID, text });
  execSync(`redis-cli -u "${REDIS_URL}" PUBLISH "${KIM_OUT}" '${payload.replace(/'/g,"'\\''")}'`, { stdio:'ignore' });
}

try {
  const cmd = path.join(ROOT, 'g/tools/services/verify_freeze_proofing_precise.zsh');
  execSync(`${cmd}`, { stdio:'inherit' });
  // Grab the most recent precise report
  const rep = execSync(`ls -1t "${ROOT}/g/reports"/251021_verification_precise_* | head -n1`).toString().trim();
  const body = readFileSync(rep, 'utf8');
  const pass = body.includes('✅ OVERALL: PASS') || (!body.includes('❌') && body.includes('PASS'));
  publish(`${pass ? '✅' : '❌'} Nightly Freeze-Proofing: ${pass ? 'PASS' : 'CHECK REPORT'}\n${rep}`);
} catch (e) {
  publish(`❌ Nightly Freeze-Proofing failed to run: ${e.message}`);
  process.exit(1);
}
