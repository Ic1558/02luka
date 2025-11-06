#!/usr/bin/env node
/* Simple event coordinator: SUB ci:events -> call local actions */
const { spawn } = require('node:child_process');
const { createClient } = require('redis');

const REDIS_URL = process.env.LUKA_REDIS_URL || 'redis://127.0.0.1:6379';
const CHANNEL   = 'ci:events';

function sh(cmd, args=[]) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: 'inherit' });
    p.on('close', (code) => code === 0 ? resolve() : reject(new Error(cmd+' exit '+code)));
  });
}

(async () => {
  const sub = createClient({ url: REDIS_URL });
  sub.on('error', (e) => console.error('Redis error:', e));
  await sub.connect();
  await sub.subscribe(CHANNEL, async (msg) => {
    try {
      const ev = JSON.parse(msg);
      const { type, pr, repo } = ev;
      if (!type || !pr) return;

      // Routing
      if (type === 'pr.fail.detected') {
        // auto rerun (safe)
        await sh('node', [
          `${process.env.HOME}/02luka/tools/puppeteer/run.mjs`,
          'pr-rerun',
          '--url', `https://github.com/${repo}/pull/${pr}`
        ]);
        // emit done
        const pub = createClient({ url: REDIS_URL });
        await pub.connect();
        await pub.publish(CHANNEL, JSON.stringify({
          type: 'pr.rerun.done',
          repo, pr,
          time: new Date().toISOString()
        }));
        await pub.quit();
      }

      if (type === 'pr.rerun.request') {
        await sh('node', [
          `${process.env.HOME}/02luka/tools/puppeteer/run.mjs`,
          'pr-rerun',
          '--url', `https://github.com/${repo}/pull/${pr}`
        ]);
      }
    } catch (e) {
      console.error('handle-event error:', e?.message || e);
    }
  });
  console.log(`[ci-coordinator] subscribed ${CHANNEL} on ${REDIS_URL}`);
})();

