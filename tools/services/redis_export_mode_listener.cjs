const { createClient } = require('redis');
const { writeFileSync, mkdirSync } = require('fs');
const { dirname } = require('path');

const CHAN = process.env.CLC_EXPORT_MODE_CHANNEL || 'gg:clc:export_mode';
const STATE_FILE = process.env.CLC_EXPORT_STATE_FILE || __dirname + '/../../state/clc_export_mode.env';
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

function writeState(mode, dir) {
  mkdirSync(dirname(STATE_FILE), { recursive: true });
  const stamp = new Date().toISOString();
  let body = `MODE=${mode}\nLOCAL_DIR=${dir||''}\nUPDATED_AT=${stamp}\n`;
  writeFileSync(STATE_FILE + '.tmp', body);
  require('fs').renameSync(STATE_FILE + '.tmp', STATE_FILE);
  console.log(`[state] ${STATE_FILE} <- MODE=${mode} LOCAL_DIR=${dir||''}`);
}

(async () => {
  const sub = createClient({ url: REDIS_URL });
  sub.on('error', (e) => console.error('redis error', e));
  await sub.connect();
  console.log(`[sub] ${REDIS_URL} # ${CHAN}`);
  await sub.subscribe(CHAN, (msg) => {
    try {
      const m = JSON.parse(msg);
      if (!m.mode) return;
      const mode = String(m.mode);
      if (!['off','local','drive'].includes(mode)) return;
      writeState(mode, m.dir);
    } catch(e) {
      console.error('bad message', msg, e);
    }
  });
})();
