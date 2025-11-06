// tools/ci_observer.cjs

import fs from 'fs';
import path from 'path';
import process from 'process';
import { createClient } from 'redis';

const REDIS_URL = process.env.LUKA_REDIS_URL || 'redis://127.0.0.1:6379';
const outDir = path.resolve(process.cwd(), 'g/reports/ci');
const statusFile = path.join(outDir, 'observer_status.json');
const logFile = path.join(outDir, 'observer.log');

if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

function appendLog(line) {
  fs.appendFileSync(logFile, `[${new Date().toISOString()}] ${line}\n`);
}

function readStatus() {
  try { return JSON.parse(fs.readFileSync(statusFile, 'utf8')); }
  catch { return { startedAt: new Date().toISOString(), counts: {}, lastEvent: null }; }
}

function writeStatus(s) {
  fs.writeFileSync(statusFile, JSON.stringify(s, null, 2));
}

async function main() {
  appendLog(`starting ci_observer (url=${REDIS_URL})`);
  const sub = createClient({ url: REDIS_URL });
  sub.on('error', (e) => appendLog(`redis error: ${e.message}`));
  await sub.connect();

  const channels = ['ci:events', 'ci:status'];
  for (const ch of channels) {
    await sub.subscribe(ch, (raw) => {
      const now = new Date().toISOString();
      let payload = raw;
      try { payload = JSON.parse(raw); } catch (_) {}
      appendLog(`recv ${ch}: ${typeof payload === 'string' ? payload : JSON.stringify(payload)}`);

      const status = readStatus();
      status.lastEvent = { channel: ch, at: now, payload };
      status.lastSeenAt = now;
      status.counts[ch] = (status.counts[ch] || 0) + 1;
      writeStatus(status);
    });
  }

  process.on('SIGINT', async () => {
    appendLog('SIGINT received, closing...');
    try { await sub.quit(); } catch {}
    process.exit(0);
  });
  process.on('SIGTERM', async () => {
    appendLog('SIGTERM received, closing...');
    try { await sub.quit(); } catch {}
    process.exit(0);
  });
}

main().catch((e) => {
  appendLog(`fatal: ${e.stack || e.message}`);
  process.exit(1);
});

